from kivy.uix.widget cimport Widget

cdef class Layout(Widget):
    cdef object _trigger_layout
    cpdef do_layout(self, *largs)
    cpdef add_widget(self, Widget widget, int index=0)
    cpdef remove_widget(self, Widget widget)
