from kivy._event cimport EventDispatcher
from kivy.properties cimport AliasProperty, BooleanProperty, DictProperty, ListProperty, NumericProperty, ObjectProperty, Property, ReferenceListProperty, StringProperty

cdef extern from "Python.h":
    object PyWeakref_NewProxy(object ob, object callback)
    
# references to all the destructors widgets (partial method with widget uid as key.)
cdef dict _widget_destructors = {}
cdef void _widget_destroctor(int *uid, object r)

cdef Widget(EventDispatcher):
    cdef object __weakref__
    cdef public tuple __events__
    cdef object _canvas
    cdef dict _context
    cdef object _proxy_ref
    cpdef bool __eq__(self, Widget other)
    cpdef int __hash__(self)
    cpdef bool collide_point(self, float x, float y)
    cpdef bool collide_widget(self, Widget wid)
    cpdef bool on_touch_down(self, object touch)
    cpdef bool on_touch_move(self, object touch)
    cpdef bool on_touch_up(self, object touch)
    cpdef add_widget(self, Widget widget, int index=0)
    cpdef remove_widget(self, Widget widget)
    cpdef object get_root_window(self)
    cpdef object get_parent_window(self)
    cpdef tuple to_local(self, float x, float y, bool relative=False)
    cpdef tuple to_widget(self, float x, float y, bool relative=False)
    cpdef tuple to_parent(self, float x, float y, bool relative=False)
    cpdef tuple to_window(self, float x, float y, bool initial=True, bool relative=False)
    cdef public Property center, center_x, center_y, children, cls, disabled, height, id, ids, opacity, parent, pos, pos_hint, right, size, size_hint, size_hint_x, size_hint_y, top, width, x, y
