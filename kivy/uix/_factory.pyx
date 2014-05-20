class FactoryException(Exception):
    pass

cdef class Machine:

    def __cinit__(self, module, cls, is_template, baseclasses, filename):
        self.module = module
        self.cls = cls
        self.is_template = is_template
        self.baseclasses = baseclasses
        self.filename = filename


cdef class FactoryBase(object):

    def __cinit__(self):
        self.classes = {}
        
    cdef _create_machine(self, object cls, str module, bint is_template, str baseclasses, str filename):
        cdef object machine = Machine(module, cls, is_template, baseclasses, filename)
        return machine

    cpdef bint is_template(self, str classname):
        if classname in self.classes:
            return self.classes[classname].is_template
        else:
            return 0

    cpdef register(self, str classname, object cls=None, str module=None, bint is_template=0, str baseclasses=None, str filename=None):
        if cls is None and module is None and baseclasses is None:
            raise ValueError('You must specify either cls= or module= or baseclasses=')
        elif classname in self.classes:
            return

        self.classes[classname] = self._create_machine(module, cls, is_template, baseclasses, filename)

    def unregister(self, *classnames):
        for classname in classnames:
            if classname in self.classes:
                self.classes.pop(classname)

    cpdef unregister_from_filename(self, str filename):
        cpdef list to_remove = [x for x in self.classes if self.classes[x].filename == filename]
        for name in to_remove:
            del self.classes[name]

    def __getattr__(self, name):
        cdef dict classes = self.classes
        if name not in classes:
            if name[0] == name[0].lower():
                # if trying to access attributes like checking for `bind`
                # then raise AttributeError
                raise AttributeError
            raise FactoryException('Unknown class {!s}'.format(name))

        item = classes[name]
        cls = item.cls

        # No class to return, import the module
        if cls is None:
            if item.module:
                module = __import__(name=item.module, fromlist='.')
                if not hasattr(module, name):
                    raise FactoryException('No class named {!s} in module {!s}'.format(name, item.module))
                cls = getattr(module, name)
                self.classes[name] = self._create_machine(item.module, cls, item.is_template, item.baseclasses, item.filename)

            elif item.baseclasses:
                rootwidgets = []
                for basecls in item.baseclasses.split('+'):
                    rootwidgets.append(self.get(basecls))
                cls = type(name, tuple(rootwidgets), {})
                self.classes[name] = self._create_machine(item.module, cls, item.is_template, item.baseclasses, item.filename)

            else:
                raise FactoryException('No information to create the class')

        return cls

    def get(self, *args):
        return self.__getattr__(*args)
