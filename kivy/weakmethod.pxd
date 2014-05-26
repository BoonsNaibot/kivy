cdef extern from "Python.h":
    object PyWeakref_NewRef(object ob, object callback)
    object PyWeakref_GetObject(object ref)
    void Py_XINCREF(object o)
    
cdef class WeakMethod(object):
    cdef object _obj
    cdef str _func
