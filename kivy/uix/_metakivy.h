#include <Python.h>
    

typedef struct {
    PyObject_HEAD
    } WidgetMetaclassObject;

static PyObject *WidgetMetaclass_new(PyTypeObject *subtype, PyObject *args, PyObject *kwargs)

static PyTypeObject WidgetMetaclassType = {
    PyObject_HEAD_INIT(NULL)
    0,                         /* ob_size */
    "WidgetMetaclass",         /* tp_name */
    sizeof(WidgetMetaclassObject),             /* tp_basicsize */
    0,                         /*  tp_itemsize */
    0,                         /*  tp_dealloc */
    0,                         /*  tp_print */
    0,                         /*  tp_getattr */
    0,                         /*  tp_setattr */
    0,                         /*  tp_compare */
    0,                         /*  tp_repr */
    0,                         /*  tp_as_number */
    0,                         /*  tp_as_sequence */
    0,                         /*  tp_as_mapping */
    0,                         /*  tp_hash  */
    0,                         /*  tp_call */
    0,                         /*  tp_str */
    0,                         /*  tp_getattro */
    0,                         /*  tp_setattro */
    0,                         /*  tp_as_buffer */
    Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE, /*  tp_flags */
    "WidgetMetaclass",      /*  tp_doc  */
    0,		               /*  tp_traverse */ 
    0,		               /*  tp_clear  */
    0,		               /*  tp_richcompare */ 
    0,		               /*  tp_weaklistoffset */ 
    0,		               /*  tp_iter  */
    0,		               /*  tp_iternext */ 
    0,                         /*  tp_methods  */
    0,                         /*  tp_members  */
    0,                         /*  tp_getset  */
    &PyType_Type,              /*  tp_base  */
    0,                         /*  tp_dict  */
    0,                         /*  tp_descr_get  */
    0,                         /*  tp_descr_set  */
    0,                         /*  tp_dictoffset  */
    0,                         /*  tp_init  */
    0,                         /*  tp_alloc  */
    WidgetMetaclass_new,       /*  tp_new  */
    };


PyObject *initmetaclass(PyTypeObject *type, PyObject *op, PyTypeObject *subtype, PyObject *args, PyObject *kwargs) 
{
    PyObject *t, *c;

    if (PyType_Ready(&type) < 0)
        return;

    t = PyObject_Init(op, type);

    if (t == NULL)
      return;

    Py_INCREF(&type);
    c = t.tp_new(subtype, args, kwargs);
    return c;
}
