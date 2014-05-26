cdef class WeakMethod(object):
    __slots__ = ('_obj', '_func')
    
    cdef object _get_object(self, object x):
        x = PyWeakref_GetObject(x)
        Py_XINCREF(x)
        return x

    def __cinit__(self, object method):
        try:
            if method.__self__ is not None:
                # bound method
                self._obj = PyWeakref_NewRef(method.im_self, None)
            else:
                # unbound method
                self._obj = PyWeakref_NewRef(method.im_class, None)
            self._func = method.__name__
        except AttributeError:
            # not a method
            self._obj = PyWeakref_NewRef(method, None)
            self._func = None

    def __call__(self):
        cdef object obj = self._get_object(self._obj)

        if self._func is not None:
            return getattr(obj, self._func)
        else:
            # we don't have an instance: return just the function
            return obj

    def __richcmp__(self, object other, int op):
        if op == 2:
            try:
                return type(self) is type(other) and self() == other()
            except:
                return False
        elif op == 3:
            return not self == other

    def is_dead(self):
        '''Returns True if the referenced callable was a bound method and
        the instance no longer exists. Otherwise, return False.
        '''
        return self._get_object(self._obj) is None
