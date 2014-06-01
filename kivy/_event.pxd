from cpython.ref cimport PyObject
from kivy.weakmethod cimport WeakMethod

cdef class ObjectWithUid(object):
    cdef readonly int uid

cdef class EventDispatcher(ObjectWithUid):
    cdef dict __event_stack
    cdef object __properties
    cdef dict __storage
    cdef object __weakref__
    cpdef dict properties(self)
