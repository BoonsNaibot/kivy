from kivy._event cimport EventDispatcher

cdef extern from "Python.h":
    object PyWeakref_NewProxy(object ob, object callback)
    

cdef class ExceptionHandler(object):
    pass
    

cdef class ExceptionManagerBase:
    cdef bint RAISE
    cdef bint PASS
    cdef list handlers
    cdef bint policy
    
    
cdef class EventLoopBase(EventDispatcher):
    cdef bint quit
    cdef list input_events
    cdef list postproc_modules
    cdef readonly str status
    cdef list input_providers
    cdef list input_providers_autoremove
    cdef list event_listeners
    cdef object _window
    cdef list me_list
    cpdef add_input_provider(self, provider, bint auto_remove=*)
    cpdef remove_input_provider(self, provider)
    cpdef add_event_listener(self, listener)
    cpdef remove_event_listener(self, listener)
    cpdef start(self)
    cpdef close(self)
    cdef post_dispatch_input(self, str etype, object me)
    cdef dispatch_input(self)
    cdef idle(self)
    cpdef run(self)
    cpdef exit(self)
