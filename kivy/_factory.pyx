cdef inline object _get_object(object x):
    x = PyWeakref_GetObject(x)
    Py_XINCREF(x)
    return x

class FactoryException(Exception):
    pass

cdef class Machine:
    cdef readonly object cls
    cdef readonly str module
    cdef readonly bint is_template
    cdef readonly str baseclasses
    cdef readonly str filename

    def __cinit__(self, cls, module, is_template, baseclasses, filename):
        self.cls = cls
        self.module = module
        self.is_template = is_template
        self.baseclasses = baseclasses
        self.filename = filename


cdef class FactoryBase(object):

    def __cinit__(self):
        self.classes = {}
        
    cdef _create_machine(self, object cls, str module, bint is_template, str baseclasses, str filename):
        try:
            cls = PyWeakref_NewRef(cls, None)
        finally:
            machine = Machine(cls, module, is_template, baseclasses, filename)
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

        self.classes[classname] = self._create_machine(cls, module, is_template, baseclasses, filename)

    cpdef unregister_from_filename(self, str filename):
        cdef str x
        cdef list to_remove = [x for x in self.classes if self.classes[x].filename == filename]
        for x in to_remove:
            del self.classes[x]

    def __getattr__(self, str name):
        cdef dict classes = self.classes
        if name not in classes:
            if name[0] == name[0].lower():
                # if trying to access attributes like checking for `bind`
                # then raise AttributeError
                raise AttributeError
            raise FactoryException('Unknown class {!s}'.format(name))

        item = classes[name]
        
        try:
            cls = _get_object(item.cls)
        except:
            cls = item.cls

        # No class to return, import the module
        if cls is None:
            if item.module:
                module = __import__(name=item.module, fromlist='.')
                if not hasattr(module, name):
                    raise FactoryException('No class named {!s} in module {!s}'.format(name, item.module))
                cls = getattr(module, name)
                self.classes[name] = self._create_machine(cls, item.module, item.is_template, item.baseclasses, item.filename)

            elif item.baseclasses:
                cdef list rootwidgets = []
                for basecls in item.baseclasses.split('+'):
                    rootwidgets.append(self.get(basecls))
                cls = type(name, tuple(rootwidgets), {})
                self.classes[name] = self._create_machine(cls, item.module, item.is_template, item.baseclasses, item.filename)

            else:
                raise FactoryException('No information to create the class')

        return cls

    def get(self, *args):
        return self.__getattr__(*args)

    def unregister(self, *classnames):
        for classname in classnames:
            if classname in self.classes:
                self.classes.pop(classname)
