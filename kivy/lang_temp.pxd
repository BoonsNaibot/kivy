cdef class Parser(object): 
    cdef list rules
    cdef list templates
    cdef object root
    cdef list sourcecode
    cdef list directives
    cdef dict dynamic_classes
    cdef str filename
