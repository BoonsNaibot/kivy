from cpython.ref cimport PyObject
from kivy.weakmethod cimport WeakMethod

cdef extern from "Python.h":
    PyObject *PyObject_CallMethodObjArgs(PyObject *o, PyObject *name, PyObject *args)

cdef class ObjectWithUid(object):
    cdef readonly Py_ssize_t uid

cdef class EventDispatcher(ObjectWithUid):
    cdef dict __event_stack
    cdef object __properties
    cdef dict __storage
    cdef object __weakref__
