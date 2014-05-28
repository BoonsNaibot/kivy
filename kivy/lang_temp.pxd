cdef class Parser(object): 
    cdef list rules
    cdef list templates
    cdef object root
    cdef list sourcecode
    cdef list directives
    cdef dict dynamic_classes
    cdef str filename

cdef class BuilderBase(object):
    cdef object _match_cache
    cdef list files
    cdef dict dynamic_classes
    cdef dict templates
    cdef list rules
    cdef dict rulectx
