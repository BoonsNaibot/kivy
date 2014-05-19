cdef extern from 'stdarg.h':
    ctypedef struct va_list:
        pass
    ctypedef struct fake_type:
        pass
    void va_start(va_list, void *arg)
    void *va_arg(va_list, fake_type)
    void va_end(va_list)
    fake_type char_type 'char'


cdef struct Machine:
    char module
    object cls
    bint is_template
    tuple baseclasses
    char filename

cdef class FactoryBase(object):
    cdef dict classes
