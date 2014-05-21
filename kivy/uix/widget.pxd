from kivy._event cimport EventDispatcher
from kivy.properties cimport AliasProperty, BooleanProperty, DictProperty, ListProperty, NumericProperty, ObjectProperty, Property, ReferenceListProperty, StringProperty

cdef extern from "Python.h":
    object PyWeakref_NewProxy(object ob, object callback)
    
# references to all the destructors widgets (partial method with widget uid as key.)
cdef dict _widget_destructors = {}

cdef class WidgetBase(EventDispatcher):
    cdef object __weakref__
    cdef public tuple __events__
    cdef object _canvas
    cdef public dict _context
    cdef object _proxy_ref
    cpdef add_widget(self, object widget, int index=*)
    cpdef object get_parent_window(self)
    cpdef object get_root_window(self)
    cpdef bint collide_point(self, float x, float y)
    cpdef bint collide_widget(self, object wid)
    cpdef bint on_touch_down(self, object touch)
    cpdef bint on_touch_move(self, object touch)
    cpdef bint on_touch_up(self, object touch)
    cpdef remove_widget(self, object widget)
    cpdef tuple to_local(self, float x, float y, bint relative=*)
    cpdef tuple to_parent(self, float x, float y, bint relative=*)
    cpdef tuple to_widget(self, float x, float y, bint relative=*)
    cpdef tuple to_window(self, float x, float y, bint initial=*, bint relative=*)
    cdef public Property center, center_x, center_y, children, cls, disabled, height, id, ids, opacity, parent, pos, pos_hint, right, size, size_hint, size_hint_x, size_hint_y, top, width, x, y

cdef class Widget(WidgetBase):
    pass
