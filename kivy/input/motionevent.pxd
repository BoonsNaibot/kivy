cdef class MotionEvent(object):
    cdef object device
    cdef tuple push_attrs
    cdef list push_attrs_stack
    cdef public bint is_touch
    cdef int id
    cdef object shape
    cdef list profile
    cdef readonly float dsx, dsy, dsz, dx, dy, dz, osx, osy, osz, ox, oy, oz, psx, psy, psz, px, py, pz, sx, sy, sz, x, y, z
    cdef readonly tuple pos
    cdef readonly float time_start
    cdef readonly float time_update, time_end
    cdef public bint is_double_tap 
    cdef readonly float double_tap_time
    cdef public bint is_triple_tap
    cdef readonly triple_tap_time
    cdef dict ud
    cdef public list grab_list
    cdef public object grab_exclusive_class
    cdef bint grab_state
    
    cdef depack(MotionEvent self, ...)
