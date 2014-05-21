'''
Factory object
==============

The factory can be used to automatically register any class or module
and instantiate classes from it anywhere in your project. It is an
implementation of the
`Factory Pattern <http://en.wikipedia.org/wiki/Factory_pattern>`_.

The class list and available modules are automatically generated by setup.py.

Example for registering a class/module::

    >>> from kivy.factory import Factory
    >>> Factory.register('Widget', module='kivy.uix.widget')
    >>> Factory.register('Vector', module='kivy.vector')

Example of using the Factory::

    >>> from kivy.factory import Factory
    >>> widget = Factory.Widget(pos=(456,456))
    >>> vector = Factory.Vector(9, 2)

Example using a class name::

    >>> from kivy.factory import Factory
    >>> Factory.register('MyWidget', cls=MyWidget)

By default, the first classname you register via the factory is permanent.
If you wish to change the registered class, you need to unregister the
classname before you re-assign it::

    >>> from kivy.factory import Factory
    >>> Factory.register('MyWidget', cls=MyWidget)
    >>> widget = Factory.MyWidget()
    >>> Factory.unregister('MyWidget')
    >>> Factory.register('MyWidget', cls=CustomWidget)
    >>> customWidget = Factory.MyWidget()
'''

__all__ = ('Factory', 'FactoryException')


from kivy.logger import Logger
from kivy._factory import FactoryBase, FactoryException


#: Factory instance to use for getting new classes
Factory = FactoryBase()

# Now import the file with all registers
# automatically generated by build_factory\
import kivy.factory_registers  # NOQA
Logger.info('Factory: {:d} symbols loaded'.format(len(Factory.classes)))

if __name__ == '__main__':
    Factory.register('Vector', module='kivy.vector')
    Factory.register('Widget', module='kivy.uix.widget')
