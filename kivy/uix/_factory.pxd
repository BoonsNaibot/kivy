cdef struct Machine:
    char module
    object cls
    bint is_template
    tuple baseclasses
    char filename

cdef class FactoryBase(object):
    cdef dict classes
    cdef object __getattr__(self, char *name)
    cpdef bint is_template(self, char *classname)
    cpdef unregister_from_filename(self, char *filename)
    cpdef register(self, char *classname, object cls, char *module, bint is_template, object baseclasses, char *filename)

