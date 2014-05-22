__all__ = (
    'EventLoop',
    'EventLoopBase',
    'ExceptionHandler',
    'ExceptionManagerBase',
    'ExceptionManager',
    'runTouchApp',
    'stopTouchApp',
)

from kivy.config import Config
from kivy.context import register_context

#: Instance of a :class:`ExceptionManagerBase` implementation.
ExceptionManager = register_context('ExceptionManager', ExceptionManagerBase)

#: EventLoop instance
EventLoop = EventLoopBase()


def _run_mainloop():
    '''If no window has been created, this will be the executed mainloop.'''
    while True:
        try:
            EventLoop.run()
            stopTouchApp()
            break
        except BaseException as inst:
            # use exception manager first
            r = ExceptionManager.handle_exception(inst)
            if r == ExceptionManager.RAISE:
                stopTouchApp()
                raise
            else:
                pass


def runTouchApp(widget=None, slave=False):
    '''Static main function that starts the application loop.
    You can access some magic via the following arguments:

    :Parameters:
        `<empty>`
            To make dispatching work, you need at least one
            input listener. If not, application will leave.
            (MTWindow act as an input listener)

        `widget`
            If you pass only a widget, a MTWindow will be created
            and your widget will be added to the window as the root
            widget.

        `slave`
            No event dispatching is done. This will be your job.

        `widget + slave`
            No event dispatching is done. This will be your job but
            we try to get the window (must be created by you beforehand)
            and add the widget to it. Very usefull for embedding Kivy
            in another toolkit. (like Qt, check kivy-designed)

    '''

    from kivy.input import MotionEventFactory, kivy_postproc_modules

    # Ok, we got one widget, and we are not in slave mode
    # so, user don't create the window, let's create it for him !
    if widget:
        EventLoop.ensure_window()

    # Instance all configured input
    for key, value in Config.items('input'):
        Logger.debug('Base: Create provider from %s' % (str(value)))

        # split value
        args = str(value).split(',', 1)
        if len(args) == 1:
            args.append('')
        provider_id, args = args
        provider = MotionEventFactory.get(provider_id)
        if provider is None:
            Logger.warning('Base: Unknown <%s> provider' % str(provider_id))
            continue

        # create provider
        p = provider(key, args)
        if p:
            EventLoop.add_input_provider(p, True)

    # add postproc modules
    for mod in list(kivy_postproc_modules.values()):
        EventLoop.add_postproc_module(mod)

    # add main widget
    if widget and EventLoop.window:
        if widget not in EventLoop.window.children:
            EventLoop.window.add_widget(widget)

    # start event loop
    Logger.info('Base: Start application main loop')
    EventLoop.start()

    # we are in a slave mode, don't do dispatching.
    if slave:
        return

    # in non-slave mode, they are 2 issues
    #
    # 1. if user created a window, call the mainloop from window.
    #    This is due to glut, it need to be called with
    #    glutMainLoop(). Only FreeGLUT got a gluMainLoopEvent().
    #    So, we are executing the dispatching function inside
    #    a redisplay event.
    #
    # 2. if no window is created, we are dispatching event lopp
    #    ourself (previous behavior.)
    #
    try:
        if EventLoop.window is None:
            _run_mainloop()
        else:
            EventLoop.window.mainloop()
    finally:
        stopTouchApp()


def stopTouchApp():
    '''Stop the current application by leaving the main loop'''
    if EventLoop is None:
        return
    if EventLoop.status != 'started':
        return
    Logger.info('Base: Leaving application in progress...')
    EventLoop.close()
