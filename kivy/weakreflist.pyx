cdef inline object _get_object(object x):
    x = PyWeakref_GetObject(x)
    Py_XINCREF(x)
    return x

cdef inline object _get_ref(object x, object self):
    return PyWeakref_NewRef(x, self._remove)


cdef class WeakList(list):

    def __init__(self, list items=None):
        items = items or []
        super(WeakList, self).__init__((_get_ref(x, self) for x in items))

    def __contains__(self, object item):
        return super(WeakList, self).__contains__(_get_ref(item, self))

    def __getitem__(self, object item):
        return _get_object(super(WeakList, self).__getitem__(item))

    def __getslice__(self, int i, int j):
        cdef list __getslice__ = super(WeakList, self).__getslice__(i, j)
        return [_get_object(x) for x in __getslice__] #slow?

    def __iter__(self):
        for x in super(WeakList, self).__iter__():
            yield _get_object(x)

    def __repr__(self):
        return "WeakList({!r})".format(list(self))

    def __reversed__(self, *args, **kwargs):
        for x in super(WeakList, self).__reversed__(*args, **kwargs):
            yield _get_object(x)

    def __setitem__(self, int i, object item):
        super(WeakList, self).__setitem__(i, _get_ref(item, self))

    def __setslice__(self, int i, int j, object items):
        super(WeakList, self).__setslice__(i, j, (_get_ref(x, self) for x in items))

    cpdef _remove(self, object item):
        while super(WeakList, self).__contains__(item):
            super(WeakList, self).remove(item)

    def append(self, object item):
        super(WeakList, self).append(_get_ref(item, self))

    def count(self, object item):
        return super(WeakList, self).count(_get_ref(item, self))

    def extend(self, object items):
        super(WeakList, self).extend((_get_ref(x, self) for x in items))

    def index(self, object item):
        return super(WeakList, self).index(_get_ref(item, self))

    def insert(self, int i, object item):
        super(WeakList, self).insert(i, _get_ref(item, self))
        
    def pop(self, int i=-1):
        return _get_object(super(WeakList, self).pop(i))

    def remove(self, object item):
        super(WeakList, self).remove(_get_ref(item, self))
