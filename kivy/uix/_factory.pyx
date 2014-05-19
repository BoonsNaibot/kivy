from kivy.logger import Logger


class FactoryException(Exception):
    pass


cdef class FactoryBase(object):

    classes = {}

    cpdef bint is_template(self, char *classname):
        if classname in self.classes:
            return self.classes[classname].is_template
        else:
            return 0

    cpdef register(self, char *classname, object cls=None, char *module='', bint is_template=0, object baseclasses=None, char *filename=''):
        if cls is None and module=='' and baseclasses is None:
            raise ValueError('You must specify either cls= or module= or baseclasses =')
        elif classname in self.classes:
            return

        cdef Machine machine
        machine.module = module
        machine.cls = cls
        machine.is_template = is_template
        machine.baseclasses = baseclasses
        machine.filename = filename
        self.classes[classname] = machine

    def unregister(self, *classnames):
        for classname in classnames:
            if classname in self.classes:
                self.classes.pop(classname)

    cpdef unregister_from_filename(self, char *filename):
        cdef char *x, *name
        cdef list to_remove = [x for x in self.classes if self.classes[x].filename == filename]
        for name in to_remove:
            del self.classes[name]

    cdef object __getattr__(self, char *name):
        cdef dict classes = self.classes
        if name not in classes:
            if name[0] == name[0].lower():
                # if trying to access attributes like checking for `bind`
                # then raise AttributeError
                raise AttributeError
            raise FactoryException('Unknown class <%s>' % name)

        cdef Machine *item = classes[name]
        cls = item.cls

        # No class to return, import the module
        if cls is None:
            if item.module:
                module = __import__(name=item.module, fromlist='.')
                if not hasattr(module, name):
                    raise FactoryException(
                        'No class named <%s> in module <%s>' % (
                            name, item.module))
                cls = item.cls = getattr(module, name)

            elif item.baseclasses:
                rootwidgets = []
                for basecls in item.baseclasses.split('+'):
                    rootwidgets.append(Factory.get(basecls))
                cls = item.cls = type(name, tuple(rootwidgets), {})

            else:
                raise FactoryException('No information to create the class')

        return cls

    cpdef get(self, *args):
        return self.__getattr__(*args)
