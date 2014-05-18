
__all__ = ('Layout', )

from kivy.clock import Clock

cdef class Layout(Widget):
    '''Layout interface class, used to implement every layout. See module
    documentation for more information.
    '''
    
    def __cimport__(self, **kwargs):
        self._trigger_layout = None
        super(Layout, self).__cimport__(**kwargs)

    def __init__(self, **kwargs):
        if self.__class__ == Layout:
            raise Exception('The Layout class cannot be used.')
        self._trigger_layout = Clock.create_trigger(self.do_layout, -1)
        super(Layout, self).__init__(**kwargs)

    cpdef do_layout(self, *largs):
        '''This function is called when a layout is needed by a trigger.
        If you are writing a new Layout subclass, don't call this function
        directly but use :meth:`_trigger_layout` instead.

        .. versionadded:: 1.0.8
        '''
        pass

    cpdef add_widget(self, Widget widget, int index=0):
        widget.bind(size=self._trigger_layout, size_hint=self._trigger_layout)
        return super(Layout, self).add_widget(widget, index)

    cpdef remove_widget(self, Widget widget):
        widget.unbind(size=self._trigger_layout, size_hint=self._trigger_layout)
        return super(Layout, self).remove_widget(widget)
