from kivy.weakreflist cimport WeakList
from kivy._event cimport EventDispatcher

cdef extern from "Python.h":
    object PyWeakref_NewProxy(object ob, object callback)
    

cdef class ExceptionHandler(object):
    pass
    

cdef class ExceptionManagerBase:
    cdef list handlers
    cdef bint policy
    
    
cdef class EventLoopBase(EventDispatcher):
    cdef public bint quit
    cdef list input_events
    cdef list postproc_modules
    cdef readonly str status
    cdef list input_providers
    cdef list input_providers_autoremove
    cdef list event_listeners
    cdef object _window
    cdef list me_list
    cdef bint _idle(self)
    cdef dispatch_input(self)
    cdef exit(self)
    cdef post_dispatch_input(self, str etype, object me)
    cdef remove_postproc_module(self, object mod)
    cdef stop(self)
    cpdef add_event_listener(self, object listener)
    cpdef add_input_provider(self, provider, bint auto_remove=*)
    cpdef add_postproc_module(self, object mod)
    cpdef close(self)
    cpdef remove_event_listener(self, object listener)
    cpdef remove_input_provider(self, object provider)
    cpdef run(self)
    cpdef start(self)
