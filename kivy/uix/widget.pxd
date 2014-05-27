from kivy._event cimport EventDispatcher
from kivy.properties cimport AliasProperty, BooleanProperty, DictProperty, ListProperty, NumericProperty, ObjectProperty, ReferenceListProperty, StringProperty

cdef extern from "Python.h":
    object PyWeakref_NewProxy(object ob, object callback)

cdef extern from "object.h": 
    ctypedef class __builtin__.type [object PyHeapTypeObject]:
        pass
        
cdef class WidgetMetaclass(type):
    pass

cdef class WidgetBase

cdef class Widget(WidgetBase):
    cdef object _canvas
    cdef public object _context
    cdef object _proxy_ref
    cpdef add_widget(self, WidgetBase widget, int index=*)
    cpdef object get_parent_window(self)
    cpdef object get_root_window(self)
    cpdef bint collide_point(self, float x, float y)
    cpdef bint collide_widget(self, WidgetBase wid)
    cpdef bint on_touch_down(self, object touch)
    cpdef bint on_touch_move(self, object touch)
    cpdef bint on_touch_up(self, object touch)
    cpdef clear_widgets(self, list children=*)
    cpdef remove_widget(self, WidgetBase widget)
    cpdef tuple to_local(self, float x, float y, bint relative=*)
    cpdef tuple to_parent(self, float x, float y, bint relative=*)
    cpdef tuple to_widget(self, float x, float y, bint relative=*)
    cpdef tuple to_window(self, float x, float y, bint initial=*, bint relative=*)
