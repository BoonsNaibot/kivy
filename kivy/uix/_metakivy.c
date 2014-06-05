#include <Python.h>
#if PY_VERSION_HEX < 0x02060000
  #define Py_TPFLAGS_HAVE_VERSION_TAG 0

#if PY_MAJOR_VERSION >= 3
  #define Py_TPFLAGS_CHECKTYPES 0
  #define Py_TPFLAGS_HAVE_INDEX 0
#endif

#if (PY_VERSION_HEX < 0x02060000) || (PY_MAJOR_VERSION >= 3)
  #define Py_TPFLAGS_HAVE_NEWBUFFER 0
#endif

static int WidgetTypeType_cinit_(PyObject *__pyx_v_mcs, PyObject *__pyx_args, PyObject *__pyx_kwds);

static PyObject *WidgetTypeType_new_(PyTypeObject *t, PyObject *a, PyObject *k) {
  PyObject *o = (&PyType_Type)->tp_new(t, a, k);
  if (unlikely(!o)) return 0;
  if (unlikely(WidgetTypeType_cinit_(o, a, k) < 0)) {
    Py_DECREF(o); o = 0;
  }
  return o;
}

static void WidgetTypeType_dealloc_(PyObject *o) {
  #if PY_VERSION_HEX >= 0x030400a1
  if (unlikely(Py_TYPE(o)->tp_finalize) && !_PyGC_FINALIZED(o)) {
    if (PyObject_CallFinalizerFromDealloc(o)) return;
  }
  #endif
  PyObject_GC_UnTrack(o);
  PyObject_GC_Track(o);
  (&PyType_Type)->tp_dealloc(o);
}

static int WidgetTypeType_traverse_(PyObject *o, visitproc v, void *a) {
  int e;
  if (!(&PyType_Type)->tp_traverse); else { e = (&PyType_Type)->tp_traverse(o,v,a); if (e) return e; }
  return 0;
}

static int WidgetTypeType_clear_(PyObject *o) {
  if (!(&PyType_Type)->tp_clear); else (&PyType_Type)->tp_clear(o);
  return 0;
}

static PyMethodDef WidgetTypeType_methods_[] = {
  {0, 0, 0, 0}
};

static PyTypeObject WidgetTypeType = {
    PyObject_HEAD_INIT(0, 0)
    0,                         /* ob_size */
    (char *)"kivy.uix._metakivy.WidgetTypeType",  /* tp_name */
    sizeof(struct WidgetTypeObject),  /* tp_basicsize */
    0,                         /*  tp_itemsize */
    WidgetTypeType_dealloc_,                         /*  tp_dealloc */
    0,                         /*  tp_print */
    0,                         /*  tp_getattr */
    0,                         /*  tp_setattr */
    #if PY_MAJOR_VERSION < 3
    0,                         /*  tp_compare */
    #else
    0,                         /*  reserved */
    #endif
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
    Py_TPFLAGS_DEFAULT|Py_TPFLAGS_HAVE_VERSION_TAG|Py_TPFLAGS_CHECKTYPES|Py_TPFLAGS_HAVE_NEWBUFFER|Py_TPFLAGS_BASETYPE|Py_TPFLAGS_HAVE_GC, /*tp_flags*/
    (char *)"WidgetTypeType (internal)",      /*  tp_doc  */
    WidgetTypeType_traverse_,		               /*  tp_traverse */ 
    WidgetTypeType_clear_,		               /*  tp_clear  */
    0,		               /*  tp_richcompare */ 
    0,		               /*  tp_weaklistoffset */ 
    0,		               /*  tp_iter  */
    0,		               /*  tp_iternext */ 
    WidgetTypeType_methods_,                         /*  tp_methods  */
    0,                         /*  tp_members  */
    0,                         /*  tp_getset  */
    0,                         /*  tp_base  */
    0,                         /*  tp_dict  */
    0,                         /*  tp_descr_get  */
    0,                         /*  tp_descr_set  */
    0,                         /*  tp_dictoffset  */
    0,                         /*  tp_init  */
    0,                         /*  tp_alloc  */
    WidgetTypeType_new_,                         /*  tp_new  */
    0, /*tp_free*/
    0, /*tp_is_gc*/
    0, /*tp_bases*/
    0, /*tp_mro*/
    0, /*tp_cache*/
    0, /*tp_subclasses*/
    0, /*tp_weaklist*/
    0, /*tp_del*/
    #if PY_VERSION_HEX >= 0x02060000
    0, /*tp_version_tag*/
    #endif
    #if PY_VERSION_HEX >= 0x030400a1
    0, /*tp_finalize*/
    #endif
    };

static PyMethodDef module_methods[] = {
    {NULL}  /* Sentinel */
};

#ifndef PyMODINIT_FUNC	/* declarvations for DLL import/export */
#define PyMODINIT_FUNC void
#endif
PyMODINIT_FUNC
initmetamod(void) 
{
    PyObject* m;

    if (PyType_Ready(&NoddyType) < 0)
        return;

    m = Py_InitModule3("_metakivy", module_methods,
                       "Fuck Programming.");

    if (m == NULL)
      return;

    Py_INCREF(&WidgetTypeType);
    PyModule_AddObject(m, "WidgetTypeType", (PyObject *) &WidgetTypeType);
}
