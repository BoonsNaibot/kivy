import sys
from kivy.logger import Logger
from kivy.clock import Clock
from kivy.lang import Builder


cdef class ExceptionHandler(object):
    '''Base handler that catches exceptions in :func:`runTouchApp`.
    You can subclass and extend it as follows::

        class E(ExceptionHandler):
            def handle_exception(self, inst):
                Logger.exception('Exception catched by ExceptionHandler')
                return ExceptionManager.PASS

        ExceptionManager.add_handler(E())

    All exceptions will be set to PASS, and logged to the console!
    '''

    def __init__(self):
        pass

    def handle_exception(self, object exception):
        '''Handle one exception, defaults to returning
        ExceptionManager.STOP.
        '''
        return ExceptionManager.RAISE


cdef class ExceptionManagerBase:
    '''ExceptionManager manages exceptions handlers.'''

    RAISE = 0
    PASS = 1

    def __cinit__(self):
        self.handlers = []
        self.policy = ExceptionManagerBase.RAISE

    def add_handler(self, object cls):
        '''Add a new exception handler to the stack.'''
        if not cls in self.handlers:
            self.handlers.append(cls)

    def remove_handler(self, object cls):
        '''Remove a exception handler from the stack.'''
        if cls in self.handlers:
            self.handlers.remove(cls)

    def handle_exception(self, object inst):
        '''Called when an exception occured in the runTouchApp() main loop.'''
        cdef bint r
        cdef bint ret = self.policy
        cdef object handler
        for handler in self.handlers:
            r = handler.handle_exception(inst)
            if r == ExceptionManagerBase.PASS:
                ret = r
        return ret


cdef class EventLoopBase(EventDispatcher):
    '''Main event loop. This loop handles the updating of input and
    dispatching events.
    '''

    __events__ = ('on_start', 'on_pause', 'on_stop')

    def __cinit__(self):
        self.quit = False
        self.input_events = []
        self.postproc_modules = []
        self.status = 'idle'
        self.input_providers = []
        self.input_providers_autoremove = []
        self.event_listeners = WeakList()
        self._window = None
        self.me_list = []

    cdef bint _idle(self):
        '''This function is called after every frame. By default:

           * it "ticks" the clock to the next frame.
           * it reads all input and dispatches events.
           * it dispatches `on_update`, `on_draw` and `on_flip` events to the
             window.
        '''

        # update dt
        Clock.tick()

        # read and dispatch input from providers
        self.dispatch_input()

        # flush all the canvas operation
        Builder.sync()

        # tick before draw
        Clock.tick_draw()

        # flush all the canvas operation
        Builder.sync()

        cdef object window = self.window
        if window and window.canvas.needs_redraw:
            window.dispatch('on_draw')
            window.dispatch('on_flip')

        # don't loop if we don't have listeners !
        if len(self.event_listeners) == 0:
            Logger.error('Base: No event listeners have been created')
            Logger.error('Base: Application will leave')
            self.exit()
            return False

        return self.quit

    cdef add_postproc_module(self, object mod):
        '''Add a postproc input module (DoubleTap, TripleTap, DeJitter
        RetainTouch are defaults).'''
        if mod not in self.postproc_modules:
            self.postproc_modules.append(mod)

    cdef dispatch_input(self):
        '''Called by idle() to read events from input providers, pass events to
        postproc, and dispatch final events.
        '''

        # first, aquire input events
        cdef object provider
        for provider in self.input_providers:
            provider.update(dispatch_fn=self._dispatch_input)

        # execute post-processing modules
        for mod in self.postproc_modules:
            self.input_events = mod.process(events=self.input_events)

        # real dispatch input
        cdef list input_events = self.input_events
        cdef object pop = input_events.pop
        cdef object post_dispatch_input = self.post_dispatch_input
        while input_events:
            post_dispatch_input(*pop(0))

    cdef exit(self):
        '''Close the main loop and close the window.'''
        self.close()
        if self.window is not None:
            self.window.close()

    cdef post_dispatch_input(self, str etype, object me):
        '''This function is called by dispatch_input() when we want to dispatch
        an input event. The event is dispatched to all listeners and if
        grabbed, it's dispatched to grabbed widgets.
        '''
        # update available list
        if etype == 'begin':
            self.me_list.append(me)
        elif etype == 'end':
            if me in self.me_list:
                self.me_list.remove(me)

        # dispatch to listeners
        if not me.grab_exclusive_class:
            for listener in self.event_listeners:
                listener.dispatch('on_motion', etype, me)

        # dispatch grabbed touch
        me.grab_state = True
        for _wid in me.grab_list[:]:

            # it's a weakref, call it!
            wid = _wid()
            if wid is None:
                # object is gone, stop.
                me.grab_list.remove(_wid)
                continue

            root_window = wid.get_root_window()
            if wid != root_window and root_window is not None:
                me.push()
                w, h = root_window.system_size
                me.scale_for_screen(w, h, rotation=root_window.rotation)
                parent = wid.parent
                # and do to_local until the widget
                try:
                    if parent:
                        me.apply_transform_2d(parent.to_widget)
                    else:
                        me.apply_transform_2d(wid.to_widget)
                        me.apply_transform_2d(wid.to_parent)
                except AttributeError:
                    # when using innerwindow, an app have grab the touch
                    # but app is removed. the touch can't access
                    # to one of the parent. (ie, self.parent will be None)
                    # and BAM the bug happen.
                    me.pop()
                    continue

            me.grab_current = wid

            wid._context.push()

            if etype == 'begin':
                # don't dispatch again touch in on_touch_down
                # a down event are nearly uniq here.
                # wid.dispatch('on_touch_down', touch)
                pass
            elif etype == 'update':
                if wid._context.sandbox:
                    with wid._context.sandbox:
                        wid.dispatch('on_touch_move', me)
                else:
                    wid.dispatch('on_touch_move', me)

            elif etype == 'end':
                if wid._context.sandbox:
                    with wid._context.sandbox:
                        wid.dispatch('on_touch_up', me)
                else:
                    wid.dispatch('on_touch_up', me)

            wid._context.pop()

            me.grab_current = None

            if wid != root_window and root_window is not None:
                me.pop()
        me.grab_state = False

    cdef remove_postproc_module(self, object mod):
        '''Remove a postproc module.'''
        if mod in self.postproc_modules:
            self.postproc_modules.remove(mod)

    cdef stop(self):
        '''Stop all input providers and call callbacks registered using
        EventLoop.add_stop_callback().'''

        # XXX stop in reverse order that we started them!! (like push
        # pop), very important because e.g. wm_touch and WM_PEN both
        # store old window proc and the restore, if order is messed big
        # problem happens, crashing badly without error
        cdef object provider
        for provider in reversed(self.input_providers[:]):
            provider.stop()
            if provider in self.input_providers_autoremove:
                self.input_providers_autoremove.remove(provider)
                self.input_providers.remove(provider)

        # ensure any restart will not break anything later.
        self.input_events = []

        self.status = 'stopped'
        self.dispatch('on_stop')

    cpdef add_event_listener(self, object listener):
        '''Add a new event listener for getting touch events.
        '''
        if not listener in self.event_listeners:
            self.event_listeners.append(listener)

    cpdef add_input_provider(self, object provider, bint auto_remove=0):
        '''Add a new input provider to listen for touch events.
        '''
        if provider not in self.input_providers:
            self.input_providers.append(provider)
            if auto_remove:
                self.input_providers_autoremove.append(provider)

    cpdef close(self):
        '''Exit from the main loop and stop all configured
        input providers.'''
        self.quit = True
        self.stop()
        self.status = 'closed'

    cpdef remove_event_listener(self, object listener):
        '''Remove an event listener from the list.
        '''
        if listener in self.event_listeners:
            self.event_listeners.remove(listener)

    cpdef remove_input_provider(self, object provider):
        '''Remove an input provider.
        '''
        if provider in self.input_providers:
            self.input_providers.remove(provider)

    cpdef run(self):
        '''Main loop'''
        while not self.quit:
            self._idle()
        self.exit()

    cpdef start(self):
        '''Must be called only once before run().
        This starts all configured input providers.'''
        self.status = 'started'
        self.quit = False
        for provider in self.input_providers:
            provider.start()
        self.dispatch('on_start')

    def _dispatch_input(self, *ev):
        # remove the save event for the touch if exist
        if ev in self.input_events:
            self.input_events.remove(ev)
        self.input_events.append(ev)

    def ensure_window(self):
        '''Ensure that we have a window.
        '''
        import kivy.core.window  # NOQA
        if not self.window:
            Logger.critical('App: Unable to get a Window, abort.')
            sys.exit(1)

    def idle(self):
        self._idle()

    def on_stop(self):
        '''Event handler for `on_stop` events which will be fired right
        after all input providers have been stopped.'''
        pass

    def on_pause(self):
        '''Event handler for `on_pause` which will be fired when
        the event loop is paused.'''
        pass

    def on_start(self):
        '''Event handler for `on_start` which will be fired right
        after all input providers have been started.'''
        pass

    property touches:
        def __get__(self):
            '''Return the list of all touches currently in down or move states.
            '''
            return self.me_list
            
    property window:
        def __get__(self):
            return self._window
        def __set__(self, object _window):
            if _window is not None:
                def _c(*args):
                    self._window = None
                _window = PyWeakref_NewProxy(_window, _c)

            self._window = _window

