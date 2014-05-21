
__all__ = ('Widget', 'WidgetException')

from kivy.factory import Factory
from kivy.graphics import Canvas
from kivy.base import EventLoop
from kivy.lang import Builder
from kivy.context import get_current_context
from functools import partial

cdef void _widget_destructor(int uid, object r):
    # internal method called when a widget is deleted from memory. the only
    # thing we remember about it is its uid. Clear all the associated callback
    # created in kv language.
    del _widget_destructors[uid]
    Builder.unbind_widget(uid)
    
cdef class BoundsGS:

    cdef float get_right(self):
        return self.x + self.width

    cdef set_right(self, float *value):
        self.x = value - self.width

    cdef float get_top(self):
        return self.y + self.height

    cdef set_top(self, float *value):
        self.y = value - self.height

    cdef float get_center_x(self):
        return self.x + self.width / 2.

    cdef set_center_x(self, float *value):
        self.x = value - self.width / 2.

    cdef float get_center_y(self):
        return self.y + self.height / 2.

    cdef set_center_y(self, float *value):
        self.y = value - self.height / 2.


class WidgetException(Exception):
    '''Fired when the widget gets an exception.
    '''
    pass


cdef class WidgetBase(EventDispatcher):

    __events__ = ('on_touch_down', 'on_touch_move', 'on_touch_up')
    
    def __cinit__(self, *args, **kwargs):
        self._canvas = None
        self._context = None
        self._proxy_ref = None
        Factory.register(type(self).__name__, cls=self)

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
            if self._proxy_ref:
                return self._proxy_ref
            else:
                f = partial(_widget_destructor, self.uid)
                self._proxy_ref = _proxy_ref = PyWeakref_NewProxy(self, f)
                # only f should be enough here, but it appears that is a very
                # specific case, the proxy destructor is not called if both f and
                # _proxy_ref are not together in a tuple
                _widget_destructors[self.uid] = (f, _proxy_ref)
                return _proxy_ref

    cpdef bint __eq__(self, Widget other):
        if not isinstance(other, Widget):
            return False
        return self.proxy_ref is other.proxy_ref

    cpdef int __hash__(self):
        return id(self)

    cpdef bint collide_point(self, float x, float y):
        return self.x <= x <= self.right and self.y <= y <= self.top

    cpdef bool collide_widget(self, Widget wid):
        if self.right < wid.x:
            return False
        if self.x > wid.right:
            return False
        if self.top < wid.y:
            return False
        if self.y > wid.top:
            return False
        return True

    cpdef bool on_touch_down(self, object touch):
        if self.disabled and self.collide_point(*touch.pos):
            return True
        cdef Widget *child
        for child in self.children[:]:
            if child.dispatch('on_touch_down', touch):
                return True
        else:
            return False

    cpdef bool on_touch_move(self, object touch):
        if self.disabled:
            return False
        cdef Widget *child
        for child in self.children[:]:
            if child.dispatch('on_touch_move', touch):
                return True
        else:
            return False

    cpdef bool on_touch_up(self, object touch):
        if self.disabled:
            return False
        cdef Widget *child
        for child in self.children[:]:
            if child.dispatch('on_touch_up', touch):
                return True
        else:
            return False

    cpdef add_widget(self, Widget widget, int index=0):
        if not isinstance(widget, Widget):
            raise WidgetException(
                'add_widget() can be used only with Widget classes.')

        widget = widget.__self__
        if widget is self:
            raise WidgetException('You cannot add yourself in a Widget')
        parent = widget.parent
        # check if widget is already a child of another widget
        if parent:
            raise WidgetException('Cannot add {!r}, it already has a parent {!r}'.format(widget, parent))
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

    cpdef remove_widget(self, Widget widget):
        if widget not in self.children:
            return
        self.children.remove(widget)
        self.canvas.remove(widget.canvas)
        widget.parent = None

    cpdef clear_widgets(self, object children=None):

        if not children:
            children = self.children
        cdef object remove_widget = self.remove_widget
        cdef Widget *child
        for child in children[:]:
            remove_widget(child)

    cpdef object get_root_window(self):
        if self.parent:
            return self.parent.get_root_window()

    cpdef object get_parent_window(self):
        if self.parent:
            return self.parent.get_parent_window()

    cpdef tuple to_local(self, float x, float y, bool relative=False):
        if relative:
            return (x - self.x, y - self.y)
        return (x, y)

    cpdef tuple to_widget(self, float x, float y, bool relative=False):
        if self.parent:
            x, y = self.parent.to_widget(x, y)
        return self.to_local(x, y, relative=relative)

    cpdef tuple to_parent(self, float x, float y, bool relative=False):
        if relative:
            return (x + self.x, y + self.y)
        return (x, y)

    cpdef tuple to_window(self, float x, float y, bool initial=True, bool relative=False):
        if not initial:
            x, y = self.to_parent(x, y, relative=relative)
        if self.parent:
            return self.parent.to_window(x, y, initial=False, relative=relative)
        return (x, y)

    def on_disabled(self, instance, value):
        for child in self.children:
            child.disabled = value

    def on_opacity(self, instance, value):
        canvas = self.canvas
        if canvas is not None:
            canvas.opacity = value
            
    x = NumericProperty(0)
    y = NumericProperty(0)
    width = NumericProperty(100)
    height = NumericProperty(100)
    pos = ReferenceListProperty(x, y)
    size = ReferenceListProperty(width, height)
    right = AliasProperty(BoundsGS.get_right, BoundsGS.set_right, bind=('x', 'width'))
    top = AliasProperty(BoundsGS.get_top, BoundsGS.set_top, bind=('y', 'height'))
    center_x = AliasProperty(BoundsGS.get_center_x, BoundsGS.set_center_x, bind=('x', 'width'))
    center_y = AliasProperty(BoundsGS.get_center_y, BoundsGS.set_center_y, bind=('y', 'height'))
    center = ReferenceListProperty(BoundsGS.center_x, BoundsGS.center_y)
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


cdef class Widget(WidgetBase):

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
            #current_root = Builder.idmap.get('root')
            #Builder.idmap['root'] = self
            Builder.apply(self)

        # Bind all the events
        for argument in kwargs:
            if argument[:3] == 'on_':
                self.bind(**{argument: kwargs[argument]})
