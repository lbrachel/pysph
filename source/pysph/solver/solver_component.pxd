"""
Module to hold base classes for different solver components.
"""

# local imports
from pysph.solver.base cimport Base
from pysph.solver.entity_base cimport EntityBase

# forward declaration.
cdef class ComponentManager

################################################################################
# `SolverComponent` class.
################################################################################
cdef class SolverComponent(Base):
    """
    Base class for all solver components.
    """

    # name of the component.
    cdef public str name

    # reference to the component manager.
    cdef public ComponentManager cm

    # indicates that the input entites to this component have been manually
    # added, and add_entity should not accept any more entities.
    cdef public bint accept_input_entities

    # indicates if the component is ready for execution.
    cdef public bint setup_done

    # function to perform the components computation.
    cdef int compute(self) except -1

    # python wrapper to the compute function.
    cpdef int py_compute(self) except -1

    # function to filter out unwanted entities.
    cpdef bint filter_entity(self, EntityBase entity)

    # function to add entity.
    cpdef add_entity(self, EntityBase entity)

    # function to setup the component once before execution.
    cpdef int setup_component(self) except -1

    # update the property requirements of this component
    cpdef int update_property_requirements(self) except -1

    cpdef add_entity_name(self, str name)
    cpdef remove_entity_name(self, str name)
    cpdef set_entity_names(self, list entity_names)

    cpdef add_input_entity_type(self, int etype)
    cpdef remove_input_entity_type(self, int etype)
    cpdef set_input_entity_types(self, list type_list)

################################################################################
# `UserDefinedComponent` class.
################################################################################
cdef class UserDefinedComponent(SolverComponent):
    """
    Base class to enable users to implement components in Python.
    """
    cdef int compute(self) except -1
    cpdef int py_compute(self) except -1

################################################################################
# `ComponentManager` class.
################################################################################
cdef class ComponentManager(Base):
    """
    Class to manage different components.

    **NOTES**
        - for every component, indicate if its input has to be handled by the
        component manager.
    """
    # the main dict containing all components
    cdef public dict component_dict

    # function to add this entity to all components that require their input to
    # be managed by the component manager.
    cpdef add_input(self, EntityBase entity)
    
    # adds a new component to the component manager.
    cpdef add_component(self, SolverComponent c, bint notify=*)

    # checks if property requirements for component are safe.
    cpdef bint validate_property_requirements(self, SolverComponent c) except *

    cpdef _add_particle_property(self, dict prop, int etype, str data_type=*)
    cpdef bint _check_property(
        self, SolverComponent comp, dict prop, str access_mode, int etype) except *
    cpdef _update_property_component_map(
        self, str prop, str comp_name, int etype, str access_type)

    cpdef remove_component(self, str comp_name)

    cpdef SolverComponent get_component(self, str component_name)

    cpdef get_entity_properties(self, int e_type)
    cpdef get_particle_properties(self, int e_type)

    cpdef setup_entity(self, EntityBase entity)
