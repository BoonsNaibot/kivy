cdef extern from "Python.h":
    object PyWeakref_NewRef(object ob, object callback)
    object PyWeakref_GetObject(object ref)
    object PyObject_GetAttr(object o, str name)
    void Py_XINCREF(object o)
    
cdef class WeakMethod(object):
    cdef object _obj
    cdef str _func
    cdef object _get_object(self, object x)
