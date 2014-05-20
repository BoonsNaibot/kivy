cdef class Machine:
    cdef public str module
    cdef public object cls
    cdef public bint is_template
    cdef public object baseclasses
    cdef public str filename

cdef class FactoryBase(object):
    cdef public dict classes
    cpdef bint is_template(self, str classname)
    cpdef unregister_from_filename(self, str filename)
    cpdef register(self, str classname, object cls=*, str module=*, bint is_template=*, object baseclasses=*, str filename=*)

