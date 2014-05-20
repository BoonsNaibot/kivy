cdef extern from "Python.h":
    object PyWeakref_NewRef(object ob, object callback)
    object PyWeakref_GetObject(object ref)
    void Py_XINCREF(object o)

cdef class Machine:
    cdef readonly str module
    cdef readonly object cls
    cdef readonly bint is_template
    cdef readonly str baseclasses
    cdef readonly str filename

cdef class FactoryBase(object):
    cdef public dict classes
    cpdef bint is_template(self, str classname)
    cpdef unregister_from_filename(self, str filename)
    cpdef register(self, str classname, object cls=*, str module=*, bint is_template=*, str baseclasses=*, str filename=*)

