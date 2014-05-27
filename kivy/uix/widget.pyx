
__all__ = ('Widget', 'WidgetException')

from kivy.factory import Factory
from kivy.graphics import Canvas
from kivy.base import EventLoop
from kivy.lang import Builder
from kivy.context import get_current_context
from functools import partial

# references to all the destructors widgets (partial method with widget uid as key.)
cdef dict _widget_destructors = {}

cpdef _widget_destructor(int uid, object r):
    # internal method called when a widget is deleted from memory. the only
    # thing we remember about it is its uid. Clear all the associated callback
    # created in kv language.
    del _widget_destructors[uid]
    Builder.unbind_widget(uid)

cpdef float get_right(object self):
    return self.x + self.width

cpdef set_right(object self, float value):
    self.x = value - self.width

cpdef float get_top(object self):
    return self.y + self.height

cpdef set_top(object self, float value):
    self.y = value - self.height

cpdef float get_center_x(object self):
    return self.x + self.width / 2.

cpdef set_center_x(object self, float value):
    self.x = value - self.width / 2.

cpdef float get_center_y(object self):
    return self.y + self.height / 2.

cpdef set_center_y(object self, float value):
    self.y = value - self.height / 2.


class WidgetException(Exception):
    '''Fired when the widget gets an exception.
    '''
    pass

cdef class WidgetMetaclass(type):
    '''Metaclass to automatically register new widgets for the
    :class:`~kivy.factory.Factory`

    .. warning::
        This metaclass is used by the Widget. Do not use it directly !
    '''
    def __init__(mcs, name, bases, attrs): # `__cinit__`?
        super(WidgetMetaclass, mcs).__init__(name, bases, attrs)
        Factory.register(name, cls=mcs)

WidgetBase = WidgetMetaclass('WidgetBase', (EventDispatcher, ), {'__metaclass__': WidgetMetaclass})

cdef class Widget(WidgetBase):
    __events__ = ('on_touch_down', 'on_touch_move', 'on_touch_up')
    
    def __cinit__(self, *args, **kwargs):
        self._canvas = None
        self._proxy_ref = None
        #Factory.register(self.__class__.__name__, cls=self)

    def __init__(self, **kwargs):
        # Before doing anything, ensure the windows exist.
        EventLoop.ensure_window()

        # assign the default context of the widget creation
        if self._context is None:
            self._context = get_current_context()

        super(Widget, self).__init__(**kwargs)

        # Create the default canvas if not exist
        if self.canvas is None:
            self.canvas = Canvas(opacity=self.opacity)

        # Apply all the styles
        if '__no_builder' not in kwargs:
            Builder.apply(self)

        # Bind all the events
        for argument in kwargs:
            if argument[:3] == 'on_':
                self.bind(**{argument: kwargs[argument]})

    cpdef add_widget(self, object widget, int index=0):
        if not isinstance(widget, Widget):
            raise WidgetException('add_widget() can be used only with Widget classes.')

        widget = widget.__self__
        if widget is self:
            raise WidgetException('You cannot add yourself in a Widget')

        # check if widget is already a child of another widget
        if widget.parent:
            raise WidgetException('Cannot add {!r}, it already has a parent {!r}'.format(widget, widget.parent))
        widget.parent = parent = self.proxy_ref
        # child will be disabled if added to a disabled parent
        if parent.disabled:
            widget.disabled = True

        if index == 0 or len(self.children) == 0:
            self.children.insert(0, widget)
            self.canvas.add(widget.canvas)
        else:
            canvas = self.canvas
            children = self.children
            if index >= len(children):
                index = len(children)
                next_index = 0
            else:
                next_child = children[index]
                next_index = canvas.indexof(next_child.canvas)
                if next_index == -1:
                    next_index = canvas.length()
                else:
                    next_index += 1

            children.insert(index, widget)
            # we never want to insert widget _before_ canvas.before.
            if next_index == 0 and canvas.has_before:
                next_index = 1
            canvas.insert(next_index, widget.canvas)

    cpdef clear_widgets(self, list children=None):
        if not children:
            children = self.children
        remove_widget = self.remove_widget
        for child in children[:]:
            remove_widget(child)

    cpdef bint collide_point(self, float x, float y):
        return self.x <= x <= self.right and self.y <= y <= self.top

    cpdef bint collide_widget(self, object wid):
        if self.right < wid.x:
            return False
        if self.x > wid.right:
            return False
        if self.top < wid.y:
            return False
        if self.y > wid.top:
            return False
        return True

    cpdef object get_parent_window(self):
        if self.parent:
            return self.parent.get_parent_window()

    cpdef object get_root_window(self):
        if self.parent:
            return self.parent.get_root_window()

    cpdef bint on_touch_down(self, object touch):
        if self.disabled and self.collide_point(*touch.pos):
            return True
        for child in self.children[:]:
            if child.dispatch('on_touch_down', touch):
                return True
        else:
            return False

    cpdef bint on_touch_move(self, object touch):
        if self.disabled:
            return False
        for child in self.children[:]:
            if child.dispatch('on_touch_move', touch):
                return True
        else:
            return False

    cpdef bint on_touch_up(self, object touch):
        if self.disabled:
            return False
        for child in self.children[:]:
            if child.dispatch('on_touch_up', touch):
                return True
        else:
            return False

    cpdef remove_widget(self, object widget):
        if widget in self.children:
            self.children.remove(widget)
            self.canvas.remove(widget.canvas)
            widget.parent = None

    cpdef tuple to_local(self, float x, float y, bint relative=0):
        if relative:
            return (x - self.x, y - self.y)
        return (x, y)

    cpdef tuple to_parent(self, float x, float y, bint relative=0):
        if relative:
            return (x + self.x, y + self.y)
        return (x, y)

    cpdef tuple to_widget(self, float x, float y, bint relative=0):
        if self.parent:
            x, y = self.parent.to_widget(x, y)
        return self.to_local(x, y, relative=relative)

    cpdef tuple to_window(self, float x, float y, bint initial=1, bint relative=0):
        if not initial:
            x, y = self.to_parent(x, y, relative=relative)
        if self.parent:
            return self.parent.to_window(x, y, initial=0, relative=relative)
        return (x, y)

    def __hash__(self):
        return <long><void*>self

    def __richcmp__(self, object other, int i):
        if i == 2:
            if not isinstance(other, Widget):
                return False
            return self.proxy_ref is other.proxy_ref

    def on_disabled(self, instance, value):
        for child in self.children:
            child.disabled = value

    def on_opacity(self, instance, value):
        canvas = self.canvas
        if canvas is not None:
            canvas.opacity = value

    property __self__:
        def __get__(self):
            return self
                
    property canvas:
        def __get__(self):
            return self._canvas
        
        def __set__(self, _canvas):
            self._canvas = _canvas

    property proxy_ref:
        def __get__(self):
            if self._proxy_ref is not None:
                return self._proxy_ref
            else:
                global _widget_destructors
                f = partial(_widget_destructor, self.uid)
                self._proxy_ref = _proxy_ref = PyWeakref_NewProxy(self, f)
                # only f should be enough here, but it appears that is a very
                # specific case, the proxy destructor is not called if both f and
                # _proxy_ref are not together in a tuple
                _widget_destructors[self.uid] = (f, _proxy_ref)
                return _proxy_ref

    x = NumericProperty(0)
    y = NumericProperty(0)
    width = NumericProperty(100)
    height = NumericProperty(100)
    pos = ReferenceListProperty(x, y)
    size = ReferenceListProperty(width, height)
    right = AliasProperty(get_right, set_right, bind=('x', 'width'))
    top = AliasProperty(get_top, set_top, bind=('y', 'height'))
    center_x = AliasProperty(get_center_x, set_center_x, bind=('x', 'width'))
    center_y = AliasProperty(get_center_y, set_center_y, bind=('y', 'height'))
    center = ReferenceListProperty(center_x, center_y)
    cls = ListProperty([])
    id = StringProperty(None, allownone=True)
    children = ListProperty([])
    parent = ObjectProperty(None, allownone=True)
    size_hint_x = NumericProperty(1, allownone=True)
    size_hint_y = NumericProperty(1, allownone=True)
    size_hint = ReferenceListProperty(size_hint_x, size_hint_y)
    pos_hint = ObjectProperty({})
    ids = DictProperty({})
    opacity = NumericProperty(1.0)
    disabled = BooleanProperty(False)
