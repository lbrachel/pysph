#cython: cdivision=True
from pysph.base.point cimport cPoint_new, cPoint_sub, cPoint_add

from pysph.solver.cl_utils import get_real

cdef extern from "math.h":
    double sqrt(double)

################################################################################
# `SPHPressureGradient` class.
################################################################################
cdef class SPHPressureGradient(SPHFunctionParticle):
    """
    Computes pressure gradient using the formula 

        INSERTFORMULA

    """

    def __init__(self, ParticleArray source, ParticleArray dest,
                 bint setup_arrays=True, int dim=3, **kwargs):
        
        SPHFunctionParticle.__init__(self, source, dest, setup_arrays,
                                     **kwargs)

        self.id = 'pgrad'
        self.tag = "velocity"

        self.cl_kernel_src_file = "pressure_funcs.cl"
        self.cl_kernel_function_name = "SPHPressureGradient"
        self.num_outputs = dim

    def set_src_dst_reads(self):
        self.src_reads = ['x','y','z','h','m','rho','p']
        self.dst_reads = ['x','y','z','h','rho','p','tag']

    def _set_extra_cl_args(self):
        pass

    cdef void eval_nbr(self, size_t source_pid, size_t dest_pid,
                   KernelBase kernel, double *nr):
        cdef double mb = self.s_m.data[source_pid]
        cdef double rhoa = self.d_rho.data[dest_pid]
        cdef double rhob = self.s_rho.data[source_pid]
        cdef double pa = self.d_p.data[dest_pid]
        cdef double pb = self.s_p.data[source_pid]

        cdef double ha = self.d_h.data[dest_pid]
        cdef double hb = self.s_h.data[source_pid]
        
        cdef double h = 0.5*(ha + hb)

        cdef double temp = 0.0

        cdef cPoint grad
        cdef cPoint grada
        cdef cPoint gradb

        self._src.x = self.s_x.data[source_pid]
        self._src.y = self.s_y.data[source_pid]
        self._src.z = self.s_z.data[source_pid]

        self._dst.x = self.d_x.data[dest_pid]
        self._dst.y = self.d_y.data[dest_pid]
        self._dst.z = self.d_z.data[dest_pid]

        temp = (pa/(rhoa*rhoa) + pb/(rhob*rhob))
        temp *= -mb

        if self.hks:
            grada = kernel.gradient(self._dst, self._src, ha)
            gradb = kernel.gradient(self._dst, self._src, hb)

            grad.set((grada.x + gradb.x)*0.5,
                     (grada.y + gradb.y)*0.5,
                     (grada.z + gradb.z)*0.5)

        else:            
            grad = kernel.gradient(self._dst, self._src, h)

        if self.rkpm_first_order_correction:
            pass

        if self.bonnet_and_lok_correction:
            self.bonnet_and_lok_gradient_correction(dest_pid, &grad)
        
        nr[0] += temp*grad.x
        if self.num_outputs > 1:
            nr[1] += temp*grad.y
            if self.num_outputs > 2:
                nr[2] += temp*grad.z

    def cl_eval(self, object queue, object context):

        self.set_cl_kernel_args()        

        self.cl_program.SPHPressureGradient(
            queue, self.global_sizes, self.local_sizes, *self.cl_args).wait()
        
#############################################################################


################################################################################
# `MomentumEquation` class.
################################################################################
cdef class MomentumEquation(SPHFunctionParticle):
    """
        INSERTFORMULA

    """
    #Defined in the .pxd file
    #cdef public double alpha
    #cdef public double beta
    #cdef public double gamma
    #cdef public double eta

    def __init__(self, ParticleArray source, ParticleArray dest, 
                 bint setup_arrays=True, alpha=1, beta=1, gamma=1.4, 
                 eta=0.1, int dim=3, **kwargs):

        SPHFunctionParticle.__init__(self, source, dest, setup_arrays,
                                     **kwargs)

        self.alpha = alpha
        self.beta = beta
        self.gamma = gamma
        self.eta = eta

        self.id = 'momentumequation'
        self.tag = "velocity"

        self.cl_kernel_src_file = "pressure_funcs.cl"
        self.cl_kernel_function_name = "MomentumEquation"
        self.num_outputs = dim

    def set_src_dst_reads(self):
        self.src_reads = ['x','y','z','h','m','rho','p','u','v','w','cs']
        self.dst_reads = ['x','y','z','h','rho','p',
                          'u','v','w','cs','tag']

    def _set_extra_cl_args(self):
        self.cl_args.append( get_real(self.alpha, self.dest.cl_precision) )
        self.cl_args_name.append( 'REAL const alpha' )

        self.cl_args.append( get_real(self.beta, self.dest.cl_precision) )
        self.cl_args_name.append( 'REAL const beta' )

        self.cl_args.append( get_real(self.gamma, self.dest.cl_precision) )
        self.cl_args_name.append( 'REAL const gamma' )

        self.cl_args.append( get_real(self.eta, self.dest.cl_precision) )
        self.cl_args_name.append( 'REAL const eta' )

    cdef void eval_nbr(self, size_t source_pid, size_t dest_pid,
                       KernelBase kernel, double *nr):
        cdef double Pa, Pb, rhoa, rhob, rhoab, mb
        cdef double dot, tmp
        cdef double ca, cb, mu, piab, alpha, beta, eta

        cdef double ha = self.d_h.data[dest_pid]
        cdef double hb = self.s_h.data[source_pid]

        cdef DoubleArray xgc, ygc, zgc

        cdef double hab = 0.5*(ha + hb)

        self._src.x = self.s_x.data[source_pid]
        self._src.y = self.s_y.data[source_pid]
        self._src.z = self.s_z.data[source_pid]

        self._dst.x = self.d_x.data[dest_pid]
        self._dst.y = self.d_y.data[dest_pid]
        self._dst.z = self.d_z.data[dest_pid]
        
        ca = self.d_cs.data[dest_pid]
        cb = self.s_cs.data[source_pid]
        
        #rab = Point_sub(self._dst, self._src)
        cdef cPoint rab, vab
        rab.x = self._dst.x-self._src.x
        rab.y = self._dst.y-self._src.y
        rab.z = self._dst.z-self._src.z
        
        vab.x = self.d_u.data[dest_pid]-self.s_u.data[source_pid]
        vab.y = self.d_v.data[dest_pid]-self.s_v.data[source_pid]
        vab.z = self.d_w.data[dest_pid]-self.s_w.data[source_pid]
        
        dot = cPoint_dot(vab, rab)
    
        Pa = self.d_p.data[dest_pid]
        rhoa = self.d_rho.data[dest_pid]        

        Pb = self.s_p.data[source_pid]
        rhob = self.s_rho.data[source_pid]
        mb = self.s_m.data[source_pid]

        tmp = Pa/(rhoa*rhoa) + Pb/(rhob*rhob)
        
        piab = 0
        if dot < 0:
            alpha = self.alpha
            beta = self.beta
            eta = self.eta
            gamma = self.gamma

            cab = 0.5 * (ca + cb)

            rhoab = 0.5 * (rhoa + rhob)

            mu = hab*dot
            mu /= (cPoint_norm(rab) + eta*eta*hab*hab)
            
            piab = -alpha*cab*mu + beta*mu*mu
            piab /= rhoab
    
        tmp += piab
        tmp *= -mb

        cdef cPoint grad
        cdef cPoint grada
        cdef cPoint gradb

        if self.hks:

            grada = kernel.gradient(self._dst, self._src, ha)
            gradb = kernel.gradient(self._dst, self._src, hb)
            
            grad.set((grada.x + gradb.x)*0.5,
                     (grada.y + gradb.y)*0.5,
                     (grada.z + gradb.z)*0.5)

        else:
            grad = kernel.gradient(self._dst, self._src, hab)
        
        if self.rkpm_first_order_correction:
            pass

        if self.bonnet_and_lok_correction:
            self.bonnet_and_lok_gradient_correction(dest_pid, &grad)

        nr[0] += tmp*grad.x
        if self.num_outputs > 1:
            nr[1] += tmp*grad.y
            if self.num_outputs > 2:
                nr[2] += tmp*grad.z

    def cl_eval(self, object queue, object context):

        self.set_cl_kernel_args()        

        self.cl_program.MomentumEquation(
            queue, self.global_sizes, self.local_sizes, *self.cl_args).wait()
        
        
###############################################################################
