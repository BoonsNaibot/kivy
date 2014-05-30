from cpython.ref cimport PyObject

cdef extern from 'Python.h':

    ctypedef struct WidgetMetaclassObject:
        PyObject_HEAD

cdef static PyObject *WidgetMetaclass_new(PyTypeObject *subtype, PyObject *args, PyObject *kwargs):
    cdef PyObject *name=NULL, *bases=NULL, *attrs=NULL
    cdef WidgetMetaclassObject *self = (WidgetMetaclassObject *)PyType_Type.tp_new(subtype, args, kwargs)
    if (self != NULL):
    	if (not PyArg_ParseTuple(args, "s(items){items}", &name, &bases, &attrs)):
            return NULL  
        Factory.register(name, cls=self)

    return (PyObject *)self

cdef static PyTypeObject WidgetMetaclassType:
    PyObject_HEAD_INIT(NULL)
    0,                         #ob_size
    "WidgetMetaclass",             #tp_name
    sizeof(WidgetMetaclassObject),             #tp_basicsize
    0,                         # tp_itemsize
    0,                         # tp_dealloc
    0,                         # tp_print
    0,                         # tp_getattr
    0,                         # tp_setattr
    0,                         # tp_compare
    0,                         # tp_repr
    0,                         # tp_as_number
    0,                         # tp_as_sequence
    0,                         # tp_as_mapping
    0,                         # tp_hash 
    0,                         # tp_call
    0,                         # tp_str
    0,                         # tp_getattro
    0,                         # tp_setattro
    0,                         # tp_as_buffer
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, # tp_flags
    "WidgetMetaclass",         # tp_doc 
    0,		               # tp_traverse 
    0,		               # tp_clear 
    0,		               # tp_richcompare 
    0,		               # tp_weaklistoffset 
    0,		               # tp_iter 
    0,		               # tp_iternext 
    0,                         # tp_methods 
    0,                         # tp_members 
    0,                         # tp_getset 
    &PyType_Type,              # tp_base 
    0,                         # tp_dict 
    0,                         # tp_descr_get 
    0,                         # tp_descr_set 
    0,                         # tp_dictoffset 
    0,                         # tp_init 
    0,                         # tp_alloc 
    WidgetMetaclass_new       # tp_new 


"""static PyMethodDef WidgetMetaclass_methods[]:
    {NULL}  # Sentinel

#ifndef PyMODINIT_FUNC	# declarations for DLL import/export 
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC
initwidgetmetaclass(void) 
{
    PyObject* m;

    noddy_NoddyType.tp_new = PyType_GenericNew;
    if (PyType_Ready(&noddy_NoddyType) < 0)
        return;

    m = Py_InitModule3("noddy", noddy_methods,
                       "Example module that creates an extension type.");

    Py_INCREF(&noddy_NoddyType);
    PyModule_AddObject(m, "Noddy", (PyObject *)&noddy_NoddyType);
}"""
