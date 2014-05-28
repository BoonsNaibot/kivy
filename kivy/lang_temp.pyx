
__all__ = ('Builder', 'BuilderBase', 'BuilderException',
           'Parser', 'ParserException')

import codecs
import re
import sys
from re import sub, findall
from os import environ
from os.path import join
from copy import copy
from types import CodeType
from functools import partial
from collections import OrderedDict
from kivy.factory import Factory
from kivy.logger import Logger
from kivy.utils import QueryDict
from kivy.cache import Cache
from kivy import kivy_data_dir, require
from kivy.compat import PY2, iteritems, iterkeys
from kivy.context import register_context
from kivy.resources import resource_find
import kivy.metrics as Metrics
from weakref import ref, proxy, WeakKeyDictionary, WeakValueDictionary
from kivy.weakreflist import WeakList


trace = Logger.trace
cdef object global_idmap = WeakValueDictionary()

# late import
cdef object Instruction = None

# register cache for creating new classtype (template)
Cache.register('kv.lang')

# precompile regexp expression
cdef object lang_str = re.compile('([\'"][^\'"]*[\'"])')
cdef object lang_key = re.compile('([a-zA-Z_]+)')
cdef object lang_keyvalue = re.compile('([a-zA-Z_][a-zA-Z0-9_.]*\.[a-zA-Z0-9_.]+)')
cdef object lang_tr = re.compile('(_\()')

# delayed calls are canvas expression triggered during an loop
cdef list _delayed_calls = []

# all the widget handlers, used to correctly unbind all the callbacks then the
# widget is deleted
cdef dict _handlers = {}


cdef class ProxyApp(object):
    # proxy app object
    # taken from http://code.activestate.com/recipes/496741-object-proxying/

    __slots__ = ('_obj',)
    cdef object _obj

    def __cinit__(self):
        self._obj = None

    cdef object _ensure_app(self):
        cdef object app = object.__getattribute__(self, '_obj')
        if app is None:
            from kivy.app import App
            self._obj = app = App.get_running_app()
            # Clear cached application instance, when it stops
            app.bind(on_stop=lambda instance: object.__setattr__(self, '_obj', None))
        return app

    def __getattribute__(self, name):
        object.__getattribute__(self, '_ensure_app')()
        return getattr(object.__getattribute__(self, '_obj'), name)

    def __delattr__(self, name):
        object.__getattribute__(self, '_ensure_app')()
        delattr(object.__getattribute__(self, '_obj'), name)

    def __setattr__(self, name, value):
        object.__getattribute__(self, '_ensure_app')()
        setattr(object.__getattribute__(self, '_obj'), name, value)

    def __bool__(self):
        object.__getattribute__(self, '_ensure_app')()
        return bool(object.__getattribute__(self, '_obj'))

    def __str__(self):
        object.__getattribute__(self, '_ensure_app')()
        return str(object.__getattribute__(self, '_obj'))

    def __repr__(self):
        object.__getattribute__(self, '_ensure_app')()
        return repr(object.__getattribute__(self, '_obj'))


global_idmap['app'] = ProxyApp()
global_idmap['pt'] = Metrics.pt
global_idmap['inch'] = Metrics.inch
global_idmap['cm'] = Metrics.cm
global_idmap['mm'] = Metrics.mm
global_idmap['dp'] = Metrics.dp
global_idmap['sp'] = Metrics.sp


class ParserException(Exception):
    '''Exception raised when something wrong happened in a kv file.
    '''

    def __init__(self, context, line, message):
        self.filename = context.filename or '<inline>'
        self.line = line
        sourcecode = context.sourcecode
        sc_start = max(0, line - 2)
        sc_stop = min(len(sourcecode), line + 3)
        sc = ['...']
        for x in range(sc_start, sc_stop):
            if x == line:
                sc += ['>> %4d:%s' % (line + 1, sourcecode[line][1])]
            else:
                sc += ['   %4d:%s' % (x + 1, sourcecode[x][1])]
        sc += ['...']
        sc = '\n'.join(sc)

        message = 'Parser: File "%s", line %d:\n%s\n%s' % (
            self.filename, self.line + 1, sc, message)
        super(ParserException, self).__init__(message)


class BuilderException(ParserException):
    '''Exception raised when the Builder failed to apply a rule on a widget.
    '''
    pass


cdef class ParserRuleProperty(object):
    '''Represent a property inside a rule.
    '''

    __slots__ = ('ctx', 'line', 'name', 'value', 'co_value',
                 'watched_keys', 'mode', 'count')
    #: Associated parser
    cdef object ctx
    cdef int line
    cdef str ame
    cdef object value
    cdef object co_value
    cdef str mode
    cdef list watched_keys
    cdef int count

    def __cinit__(self, object ctx, int line, str name, object value):
        #: Associated parser
        self.ctx = ctx
        #: Line of the rule
        self.line = line
        #: Name of the property
        self.name = name
        #: Value of the property
        self.value = value
        #: Compiled value
        self.co_value = None
        #: Compilation mode
        self.mode = None
        #: Watched keys
        self.watched_keys = None
        #: Stats
        self.count = 0

    cdef precompile(self):
        cdef str name = self.name
        cdef object value = self.value

        # first, remove all the string from the value
        cdef object tmp = sub(lang_str, '', self.value)

        # detecting how to handle the value according to the key name
        cdef str mode = self.mode
        if self.mode is None:
            self.mode = mode = 'exec' if name[:3] == 'on_' else 'eval'
        if mode == 'eval':
            # if we don't detect any string/key in it, we can eval and give the
            # result
            if re.search(lang_key, tmp) is None:
                self.co_value = eval(value)
                return

        # ok, we can compile.
        cdef str value = '\n' * self.line + value
        self.co_value = compile(value, self.ctx.filename or '<string>', mode)

        # for exec mode, we don't need to watch any keys.
        if mode == 'exec':
            return

        # now, detect obj.prop
        # first, remove all the string from the value
        tmp = sub(lang_str, '', value)
        # detect key.value inside value, and split them
        cdef list wk = list(set(findall(lang_keyvalue, tmp)))
        if len(wk):
            self.watched_keys = [x.split('.') for x in wk]
        if findall(lang_tr, tmp):
            if self.watched_keys:
                self.watched_keys += [['_']]
            else:
                self.watched_keys = [['_']]

    def __repr__(self):
        return '<ParserRuleProperty name=%r filename=%s:%d ' \
               'value=%r watched_keys=%r>' % (
                   self.name, self.ctx.filename, self.line + 1,
                   self.value, self.watched_keys)


cdef class ParserRule(object):
    '''Represents a rule, in terms of the Kivy internal language.
    '''

    __slots__ = ('ctx', 'line', 'name', 'children', 'id', 'properties',
                 'canvas_before', 'canvas_root', 'canvas_after',
                 'handlers', 'level', 'cache_marked', 'avoid_previous_rules')

    cdef int level
    cdef object ctx
    cdef int line
    cdef str name
    cdef list children
    cdef int id
    cdef dict properties
    cdef object canvas_root
    cdef object canvas_before
    cdef object canvas_after
    cdef list handlers
    cdef list cache_marked
    cdef bint avoid_previous_rules

    def __cinit__(self, object ctx, int line, str name, int level):
        #: Level of the rule in the kv
        self.level = level
        #: Associated parser
        self.ctx = ctx
        #: Line of the rule
        self.line = line
        #: Name of the rule
        self.name = name
        #: List of children to create
        self.children = []
        #: Id given to the rule
        self.id = None
        #: Properties associated to the rule
        self.properties = OrderedDict()
        #: Canvas normal
        self.canvas_root = None
        #: Canvas before
        self.canvas_before = None
        #: Canvas after
        self.canvas_after = None
        #: Handlers associated to the rule
        self.handlers = []
        #: Properties cache list: mark which class have already been checked
        self.cache_marked = WeakList()
        #: Indicate if any previous rules should be avoided.
        self.avoid_previous_rules = False

    def __init__(self, ctx, line, name, level):
        super(ParserRule, self).__init__()

        if level == 0:
            self._detect_selectors()
        else:
            self._forbid_selectors()

    cdef precompile(self):
        cdef object x
        for x in self.properties.values():
            x.precompile()
        for x in self.handlers:
            x.precompile()
        for x in self.children:
            x.precompile()
        if self.canvas_before:
            self.canvas_before.precompile()
        if self.canvas_root:
            self.canvas_root.precompile()
        if self.canvas_after:
            self.canvas_after.precompile()

    cdef create_missing(self, widget):
        # check first if the widget class already been processed by this rule
        cdef class cls = widget.__class__
        if cls in self.cache_marked:
            return
        self.cache_marked.append(cls)
        cdef str name
        for name in self.properties:
            if hasattr(widget, name):
                continue
            value = self.properties[name].co_value
            if type(value) is CodeType:
                value = None
            widget.create_property(name, value)

    cdef _forbid_selectors(self):
        cdef char *c = self.name[0]
        if c == '<' or c == '[':
            raise ParserException(
                self.ctx, self.line,
                'Selectors rules are allowed only at the first level')

    cdef _detect_selectors(self):
        cdef char *c = self.name[0]
        if c == '<':
            self._build_rule()
        elif c == '[':
            self._build_template()
        else:
            if self.ctx.root is not None:
                raise ParserException(
                    self.ctx, self.line,
                    'Only one root object is allowed by .kv')
            self.ctx.root = proxy(self)

    cdef _build_rule(self):
        cdef str name = self.name
        if __debug__:
            trace('Builder: build rule for {!s}'.format(name))
        if name[0] != '<' or name[-1] != '>':
            raise ParserException(self.ctx, self.line,
                                  'Invalid rule (must be inside <>)')

        # if the very first name start with a -, avoid previous rules
        name = name[1:-1]
        if name[:1] == '-':
            self.avoid_previous_rules = True
            name = name[1:]

        cdef list rules = name.split(',')
        cdef str rule
        for rule in rules:
            crule = None

            if not len(rule):
                raise ParserException(self.ctx, self.line,
                                      'Empty rule detected')

            if '@' in rule:
                # new class creation ?
                # ensure the name is correctly written
                rule, baseclasses = rule.split('@', 1)
                if not re.match(lang_key, rule):
                    raise ParserException(self.ctx, self.line,
                                          'Invalid dynamic class name')

                # save the name in the dynamic classes dict.
                self.ctx.dynamic_classes[rule] = baseclasses
                crule = ParserSelectorName(rule)

            else:
                # classical selectors.

                if rule[0] == '.':
                    crule = ParserSelectorClass(rule[1:])
                elif rule[0] == '#':
                    crule = ParserSelectorId(rule[1:])
                else:
                    crule = ParserSelectorName(rule)

            self.ctx.rules.append((crule, self))

    cdef _build_template(self):
        cdef str name = self.name
        if __debug__:
            trace('Builder: build template for {!s}'.format(name))
        if name[0] != '[' or name[-1] != ']':
            raise ParserException(self.ctx, self.line,
                                  'Invalid template (must be inside [])')
        cdef str item_content = name[1:-1]
        if not '@' in item_content:
            raise ParserException(self.ctx, self.line,
                                  'Invalid template name (missing @)')
        template_name, template_root_cls = item_content.split('@')
        self.ctx.templates.append((template_name, template_root_cls, self))

    def __repr__(self):
        return '<ParserRule name={!r}>'.format(self.name)


cdef class Parser(object):
    '''Create a Parser object to parse a Kivy language file or Kivy content.
    '''

    cdef tuple PROP_ALLOWED = ('canvas.before', 'canvas.after')
    cdef list CLASS_RANGE = list(range(ord('A'), ord('Z') + 1))
    cdef tuple PROP_RANGE = (list(range(ord('A'), ord('Z') + 1)) +
                             list(range(ord('a'), ord('z') + 1)) +
                             list(range(ord('0'), ord('9') + 1)) + [ord('_')])

    __slots__ = ('rules', 'templates', 'root', 'sourcecode',
                 'directives', 'filename', 'dynamic_classes')    
    cdef list rules
    cdef list templates
    cdef object root
    cdef list sourcecode
    cdef list directives
    cdef dict dynamic_classes
    cdef str filename

    def __cinit__(self, **kwargs):
        self.rules = []
        self.templates = []
        self.root = None
        self.sourcecode = []
        self.directives = []
        self.dynamic_classes = {}
        self.filename = kwargs.get('filename', None)

    def __init__(self, **kwargs):
        content = kwargs.get('content', None)
        if content is None:
            raise ValueError('No content passed')
        self.parse(content)

    cdef execute_directives(self):
        for ln, cmd in self.directives:
            cmd = cmd.strip()
            if __debug__:
                trace('Parser: got directive <{!s}>'.format(cmd))
            if cmd[:5] == 'kivy ':
                version = cmd[5:].strip()
                if len(version.split('.')) == 2:
                    version += '.0'
                require(version)
            elif cmd[:4] == 'set ':
                try:
                    name, value = cmd[4:].strip().split(' ', 1)
                except:
                    Logger.exception('')
                    raise ParserException(self, ln, 'Invalid directive syntax')
                try:
                    value = eval(value)
                except:
                    Logger.exception('')
                    raise ParserException(self, ln, 'Invalid value')
                global_idmap[name] = value

            elif cmd[:7] == 'import ':
                package = cmd[7:].strip()
                l = package.split(' ')
                if len(l) != 2:
                    raise ParserException(self, ln, 'Invalid import syntax')
                alias, package = l
                try:
                    if package not in sys.modules:
                        try:
                            mod = __import__(package)
                        except ImportError:
                            mod = __import__('.'.join(package.split('.')[:-1]))
                        # resolve the whole thing
                        for part in package.split('.')[1:]:
                            mod = getattr(mod, part)
                    else:
                        mod = sys.modules[package]
                    global_idmap[alias] = mod
                except ImportError:
                    Logger.exception('')
                    raise ParserException(self, ln,
                                          'Unable to import package {!r}'.format(package))
            else:
                raise ParserException(self, ln, 'Unknown directive')

    cdef parse(self, str content):
        '''Parse the contents of a Parser file and return a list
        of root objects.
        '''
        # Read and parse the lines of the file
        cdef list lines = content.splitlines()
        if not lines:
            return
        cdef int num_lines = len(lines)
        cdef list lines = list(zip(list(xrange(num_lines)), lines))
        self.sourcecode = lines[:]

        if __debug__:
            trace('Parser: parsing {:d} lines'.format(num_lines))

        # Strip all comments
        self.strip_comments(lines)

        # Execute directives
        self.execute_directives()

        # Get object from the first level
        objects, remaining_lines = self.parse_level(0, lines)

        # Precompile rules tree
        for rule in objects:
            rule.precompile()

        # After parsing, there should be no remaining lines
        # or there's an error we did not catch earlier.
        if remaining_lines:
            ln, content = remaining_lines[0]
            raise ParserException(self, ln, 'Invalid data (not parsed)')

    cdef strip_comments(self, list lines):
        '''Remove all comments from all lines in-place.
           Comments need to be on a single line and not at the end of a line.
           i.e. a comment line's first non-whitespace character must be a #.
        '''
        # extract directives
        for ln, line in lines[:]:
            stripped = line.strip()
            if stripped[:2] == '#:':
                self.directives.append((ln, stripped[2:]))
            if stripped[:1] == '#':
                lines.remove((ln, line))
            if not stripped:
                lines.remove((ln, line))

    cdef parse_level(self, int level, list lines, int spaces=0):
        '''Parse the current level (level * spaces) indentation.
        '''
        cdef int indent = spaces * level if spaces > 0 else 0
        cdef list objects = []

        cdef object current_object = None
        cdef object current_property = None
        cdef object current_propobject = None
        cdef int i = 0
        while i < len(lines):
            line = lines[i]
            ln, content = line

            # Get the number of space
            tmp = content.lstrip(' \t')

            # Replace any tab with 4 spaces
            tmp = content[:len(content) - len(tmp)]
            tmp = tmp.replace('\t', '    ')

            # first indent designates the indentation
            if spaces == 0:
                spaces = len(tmp)

            count = len(tmp)

            if spaces > 0 and count % spaces != 0:
                raise ParserException(self, ln,
                                      'Invalid indentation, '
                                      'must be a multiple of '
                                      '{!s} spaces'.format(spaces))
            content = content.strip()
            rlevel = count // spaces if spaces > 0 else 0

            # Level finished
            if count < indent:
                return objects, lines[i - 1:]

            # Current level, create an object
            elif count == indent:
                x = content.split(':', 1)
                if not len(x[0]):
                    raise ParserException(self, ln, 'Identifier missing')
                if len(x) == 2 and len(x[1]):
                    raise ParserException(self, ln,
                                          'Invalid data after declaration')
                name = x[0]
                # if it's not a root rule, then we got some restriction
                # aka, a valid name, without point or everything else
                if count != 0:
                    if False in [ord(z) in Parser.PROP_RANGE for z in name]:
                        raise ParserException(self, ln, 'Invalid class name')

                current_object = ParserRule(self, ln, x[0], rlevel)
                current_property = None
                objects.append(current_object)

            # Next level, is it a property or an object ?
            elif count == indent + spaces:
                x = content.split(':', 1)
                if not len(x[0]):
                    raise ParserException(self, ln, 'Identifier missing')

                # It's a class, add to the current object as a children
                current_property = None
                name = x[0]
                if ord(name[0]) in Parser.CLASS_RANGE or name[0] == '+':
                    _objects, _lines = self.parse_level(
                        level + 1, lines[i:], spaces)
                    current_object.children = _objects
                    lines = _lines
                    i = 0

                # It's a property
                else:
                    if name not in Parser.PROP_ALLOWED:
                        if not all(ord(z) in Parser.PROP_RANGE for z in name):
                            raise ParserException(self, ln,
                                                  'Invalid property name')
                    if len(x) == 1:
                        raise ParserException(self, ln, 'Syntax error')
                    value = x[1].strip()
                    if name == 'id':
                        if len(value) <= 0:
                            raise ParserException(self, ln, 'Empty id')
                        if value in ('self', 'root'):
                            raise ParserException(
                                self, ln,
                                'Invalid id, cannot be "self" or "root"')
                        current_object.id = value
                    elif len(value):
                        rule = ParserRuleProperty(self, ln, name, value)
                        if name[:3] == 'on_':
                            current_object.handlers.append(rule)
                        else:
                            current_object.properties[name] = rule
                    else:
                        current_property = name
                        current_propobject = None

            # Two more levels?
            elif count == indent + 2 * spaces:
                if current_property in (
                        'canvas', 'canvas.after', 'canvas.before'):
                    _objects, _lines = self.parse_level(
                        level + 2, lines[i:], spaces)
                    rl = ParserRule(self, ln, current_property, rlevel)
                    rl.children = _objects
                    if current_property == 'canvas':
                        current_object.canvas_root = rl
                    elif current_property == 'canvas.before':
                        current_object.canvas_before = rl
                    else:
                        current_object.canvas_after = rl
                    current_property = None
                    lines = _lines
                    i = 0
                else:
                    if current_propobject is None:
                        current_propobject = ParserRuleProperty(
                            self, ln, current_property, content)
                        if current_property[:3] == 'on_':
                            current_object.handlers.append(current_propobject)
                        else:
                            current_object.properties[current_property] = \
                                current_propobject
                    else:
                        current_propobject.value += '\n' + content

            # Too much indentation, invalid
            else:
                raise ParserException(self, ln,
                                      'Invalid indentation (too many levels)')

            # Check the next line
            i += 1

        return objects, []


def get_proxy(object widget):
    try:
        return widget.proxy_ref
    except AttributeError:
        return widget


def custom_callback(__kvlang__, idmap, *largs, **kwargs):
    idmap['args'] = largs
    exec(__kvlang__.co_value, idmap)


def create_handler(iself, element, key, value, rule, idmap, delayed=False):
    locals()['__kvlang__'] = rule

    # create an handler
    cdef int uid = iself.uid
    if uid not in _handlers:
        _handlers[uid] = []

    idmap = copy(idmap)
    idmap.update(global_idmap)
    idmap['self'] = iself.proxy_ref

    def call_fn(*args):
        if __debug__:
            trace('Builder: call_fn %s, key=%s, value=%r, %r' % (
                element, key, value, rule.value))
        rule.count += 1
        e_value = eval(value, idmap)
        if __debug__:
            trace('Builder: call_fn => value=%r' % (e_value, ))
        setattr(element, key, e_value)

    def delayed_call_fn(*args):
        _delayed_calls.append(call_fn)

    fn = delayed_call_fn if delayed else call_fn

    # bind every key.value
    if rule.watched_keys is not None:
        for k in rule.watched_keys:
            try:
                f = idmap[k[0]]
                for x in k[1:-1]:
                    f = getattr(f, x)
                if hasattr(f, 'bind'):
                    f.bind(**{k[-1]: fn})
                    # make sure _handlers doesn't keep widgets alive
                    _handlers[uid].append([get_proxy(f), k[-1], fn])
            except KeyError:
                continue
            except AttributeError:
                continue

    try:
        return eval(value, idmap)
    except Exception as e:
        raise BuilderException(rule.ctx, rule.line,
                               '{}: {}'.format(e.__class__.__name__, e))


cdef class ParserSelector(object):
    cdef str key

    def __cinit__(self, key):
        self.key = key.lower()

    def __repr__(self):
        return '<%s key=%s>' % (self.__class__.__name__, self.key)

    def match(self, widget):
        raise NotImplemented()


cdef class ParserSelectorId(ParserSelector):

    def match(self, widget):
        if widget.id:
            return widget.id.lower() == self.key


cdef class ParserSelectorClass(ParserSelector):

    def match(self, widget):
        return self.key in widget.cls


cdef class ParserSelectorName(ParserSelector):

    cdef object parents

    def __cinit__(self, *args):
        self.parents = WeakKeyDictionary()

    def get_bases(self, object cls):
        cdef object base, cbase
        for base in cls.__bases__:
            if base.__name__ == 'object':
                break
            yield base
            if base.__name__ == 'Widget':
                break
            for cbase in self.get_bases(base):
                yield cbase

    def match(self, widget):
        parents = ParserSelectorName.parents
        cls = widget.__class__
        if not cls in parents:
            classes = [x.__name__.lower() for x in
                       [cls] + list(self.get_bases(cls))]
            parents[cls] = classes
        return self.key in parents[cls]


cdef class BuilderBase(object):
    '''The Builder is responsible for creating a :class:`Parser` for parsing a
    kv file, merging the results into its internal rules, templates, etc.

    By default, :class:`Builder` is a global Kivy instance used in widgets
    that you can use to load other kv files in addition to the default ones.
    '''

    cdef object _match_cache
    cdef list files
    cdef dict dynamic_classes
    cdef dict templates
    cdef list rules
    cdef dict rulectx

    def __cinit__(self):
        self._match_cache = WeakKeyDictionary()
        self.files = []
        self.dynamic_classes = {}
        self.templates = {}
        self.rules = []
        self.rulectx = {}

    def load_file(self, filename, **kwargs):
        '''Insert a file into the language builder and return the root widget
        (if defined) of the kv file.

        :parameters:
            `rulesonly`: bool, defaults to False
                If True, the Builder will raise an exception if you have a root
                widget inside the definition.
        '''
        filename = resource_find(filename) or filename
        if __debug__:
            trace('Builder: load file {!s}'.format(filename))
        with open(filename, 'r') as fd:
            kwargs['filename'] = filename
            data = fd.read()

            # remove bom ?
            if PY2:
                if data.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
                    raise ValueError('Unsupported UTF16 for kv files.')
                if data.startswith((codecs.BOM_UTF32_LE, codecs.BOM_UTF32_BE)):
                    raise ValueError('Unsupported UTF32 for kv files.')
                if data.startswith(codecs.BOM_UTF8):
                    data = data[len(codecs.BOM_UTF8):]

            return self.load_string(data, **kwargs)

    def unload_file(self, str filename):
        '''Unload all rules associated with a previously imported file.

        .. versionadded:: 1.0.8

        .. warning::

            This will not remove rules or templates already applied/used on
            current widgets. It will only effect the next widgets creation or
            template invocation.
        '''
        # remove rules and templates
        cdef tuple x
        self.rules = [x for x in self.rules if x[1].ctx.filename != filename]
        self._clear_matchcache()
        cdef dict templates = {}
        for x, y in self.templates.items():
            if y[2] != filename:
                templates[x] = y
        self.templates = templates
        if filename in self.files:
            self.files.remove(filename)

        # unregister all the dynamic classes
        Factory.unregister_from_filename(filename)

    def load_string(self, string, **kwargs):
        '''Insert a string into the Language Builder and return the root widget
        (if defined) of the kv string.

        :Parameters:
            `rulesonly`: bool, defaults to False
                If True, the Builder will raise an exception if you have a root
                widget inside the definition.
        '''
        kwargs.setdefault('rulesonly', False)
        cdef str fn, name
        self._current_filename = fn = kwargs.get('filename', None)

        # put a warning if a file is loaded multiple times
        if fn in self.files:
            Logger.warning(
                'Lang: The file {} is loaded multiples times, '
                'you might have unwanted behaviors.'.format(fn))
            
        cdef Parser parser
        try:
            # parse the string
            parser = Parser(content=string, filename=fn)

            # merge rules with our rules
            self.rules.extend(parser.rules)
            self._clear_matchcache()

            # add the template found by the parser into ours
            for name, cls, template in parser.templates:
                self.templates[name] = (cls, template, fn)
                Factory.register(name,
                                 cls=partial(self.template, name),
                                 is_template=True)

            # register all the dynamic classes
            for name, baseclasses in iteritems(parser.dynamic_classes):
                Factory.register(name, baseclasses=baseclasses, filename=fn)

            # create root object is exist
            if kwargs['rulesonly'] and parser.root:
                filename = kwargs.get('rulesonly', '<string>')
                raise Exception('The file <%s> contain also non-rules '
                                'directives' % filename)

            # save the loaded files only if there is a root without
            # template/dynamic classes
            if fn and (parser.templates or
                       parser.dynamic_classes or parser.rules):
                self.files.append(fn)

            if parser.root:
                widget = Factory.get(parser.root.name)()
                self._apply_rule(widget, parser.root, parser.root)
                return widget
        finally:
            self._current_filename = None

    def template(self, *args, **ctx):
        '''Create a specialized template using a specific context.
        .. versionadded:: 1.0.5

        With templates, you can construct custom widgets from a kv lang
        definition by giving them a context. Check :ref:`Template usage
        <template_usage>`.
        '''
        # Prevent naming clash with whatever the user might be putting into the
        # ctx as key.
        name = args[0]
        if name not in self.templates:
            raise Exception('Unknown <%s> template name' % name)
        baseclasses, rule, fn = self.templates[name]
        key = '%s|%s' % (name, baseclasses)
        cls = Cache.get('kv.lang', key)
        if cls is None:
            rootwidgets = []
            for basecls in baseclasses.split('+'):
                rootwidgets.append(Factory.get(basecls))
            cls = type(name, tuple(rootwidgets), {})
            Cache.append('kv.lang', key, cls)
        widget = cls()
        # in previous versions, ``ctx`` is passed as is as ``template_ctx``
        # preventing widgets in it from be collected by the GC. This was
        # especially relevant to AccordionItem's title_template.
        proxy_ctx = {k: get_proxy(v) for k, v in ctx.items()}
        self._apply_rule(widget, rule, rule, template_ctx=proxy_ctx)
        return widget

    def apply(self, widget):
        '''Search all the rules that match the widget and apply them.
        '''
        rules = self.match(widget)
        if __debug__:
            trace('Builder: Found %d rules for %s' % (len(rules), widget))
        if not rules:
            return
        for rule in rules:
            self._apply_rule(widget, rule, rule)

    def _clear_matchcache(self):
        BuilderBase._match_cache = WeakKeyDictionary()

    cdef _apply_rule(self, widget, rule, rootrule, template_ctx=None):
        # widget: the current instanciated widget
        # rule: the current rule
        # rootrule: the current root rule (for children of a rule)

        # will collect reference to all the id in children
        assert(rule not in self.rulectx)
        cdef dict rctx
        self.rulectx[rule] = rctx = {'ids': {'root': widget.proxy_ref},
                                     'set': [],
                                     'hdl': []}

        # extract the context of the rootrule (not rule!)
        assert(rootrule in self.rulectx)
        rctx = self.rulectx[rootrule]

        # if a template context is passed, put it as "ctx"
        if template_ctx is not None:
            rctx['ids']['ctx'] = QueryDict(template_ctx)

        # if we got an id, put it in the root rule for a later global usage
        if rule.id:
            # use only the first word as `id` discard the rest.
            rule.id = rule.id.split('#', 1)[0].strip()
            rctx['ids'][rule.id] = widget.proxy_ref
            # set id name as a attribute for root widget so one can in python
            # code simply access root_widget.id_name
            _ids = dict(rctx['ids'])
            _root = _ids.pop('root')
            _new_ids = _root.ids
            for _key in iterkeys(_ids):
                if _ids[_key] == _root:
                    # skip on self
                    continue
                _new_ids[_key] = _ids[_key]
            _root.ids = _new_ids

        # first, ensure that the widget have all the properties used in
        # the rule if not, they will be created as ObjectProperty.
        rule.create_missing(widget)

        # build the widget canvas
        if rule.canvas_before:
            with widget.canvas.before:
                self._build_canvas(widget.canvas.before, widget,
                                   rule.canvas_before, rootrule)
        if rule.canvas_root:
            with widget.canvas:
                self._build_canvas(widget.canvas, widget,
                                   rule.canvas_root, rootrule)
        if rule.canvas_after:
            with widget.canvas.after:
                self._build_canvas(widget.canvas.after, widget,
                                   rule.canvas_after, rootrule)

        # create children tree
        Factory_get = Factory.get
        Factory_is_template = Factory.is_template
        for crule in rule.children:
            cname = crule.name

            # depending if the child rule is a template or not, we are not
            # having the same approach
            cls = Factory_get(cname)

            if Factory_is_template(cname):
                # we got a template, so extract all the properties and
                # handlers, and push them in a "ctx" dictionary.
                ctx = {}
                idmap = copy(global_idmap)
                idmap.update({'root': rctx['ids']['root']})
                if 'ctx' in rctx['ids']:
                    idmap.update({'ctx': rctx['ids']['ctx']})
                try:
                    for prule in crule.properties.values():
                        value = prule.co_value
                        if type(value) is CodeType:
                            value = eval(value, idmap)
                        ctx[prule.name] = value
                    for prule in crule.handlers:
                        value = eval(prule.value, idmap)
                        ctx[prule.name] = value
                except Exception as e:
                    raise BuilderException(
                        prule.ctx, prule.line,
                        '{}: {}'.format(e.__class__.__name__, e))

                # create the template with an explicit ctx
                child = cls(**ctx)
                widget.add_widget(child)

                # reference it on our root rule context
                if crule.id:
                    rctx['ids'][crule.id] = child

            else:
                # we got a "normal" rule, construct it manually
                # we can't construct it without __no_builder=True, because the
                # previous implementation was doing the add_widget() before
                # apply(), and so, we could use "self.parent".
                child = cls(__no_builder=True)
                widget.add_widget(child)
                self.apply(child)
                self._apply_rule(child, crule, rootrule)

        # append the properties and handlers to our final resolution task
        if rule.properties:
            rctx['set'].append((widget.proxy_ref,
                                list(rule.properties.values())))
        if rule.handlers:
            rctx['hdl'].append((widget.proxy_ref, rule.handlers))

        # if we are applying another rule that the root one, then it's done for
        # us!
        if rootrule is not rule:
            del self.rulectx[rule]
            return

        # normally, we can apply a list of properties with a proper context
        try:
            rule = None
            for widget_set, rules in reversed(rctx['set']):
                for rule in rules:
                    assert(isinstance(rule, ParserRuleProperty))
                    key = rule.name
                    value = rule.co_value
                    if type(value) is CodeType:
                        value = create_handler(widget_set, widget_set, key,
                                               value, rule, rctx['ids'])
                    setattr(widget_set, key, value)
        except Exception as e:
            if rule is not None:
                raise BuilderException(rule.ctx, rule.line,
                                       '{}: {}'.format(e.__class__.__name__,
                                                       e))
            raise e

        # build handlers
        try:
            crule = None
            for widget_set, rules in rctx['hdl']:
                for crule in rules:
                    assert(isinstance(crule, ParserRuleProperty))
                    assert(crule.name.startswith('on_'))
                    key = crule.name
                    if not widget_set.is_event_type(key):
                        key = key[3:]
                    idmap = copy(global_idmap)
                    idmap.update(rctx['ids'])
                    idmap['self'] = widget_set.proxy_ref
                    widget_set.bind(**{key: partial(custom_callback,
                                                    crule, idmap)})
                    #hack for on_parent
                    if crule.name == 'on_parent':
                        Factory.Widget.parent.dispatch(widget_set.__self__)
        except Exception as e:
            if crule is not None:
                raise BuilderException(
                    crule.ctx, crule.line,
                    '{}: {}'.format(e.__class__.__name__, e))
            raise e

        # rule finished, forget it
        del self.rulectx[rootrule]

    cdef list match(self, object widget):
        '''Return a list of :class:`ParserRule` objects matching the widget.
        '''
        cdef object cache = BuilderBase._match_cache
        #k = (ref(widget.__class__), widget.id, tuple(widget.cls))
        if widget in cache:
            return cache[widget]
        cdef list rules = []
        for selector, rule in self.rules:
            if selector.match(widget):
                if rule.avoid_previous_rules:
                    del rules[:]
                rules.append(rule)
        cache[widget] = rules
        return rules

    def sync(self):
        '''Execute all the waiting operations, such as the execution of all the
        expressions related to the canvas.

        .. versionadded:: 1.7.0
        '''
        cdef set l = set(_delayed_calls)
        del _delayed_calls[:]
        for func in l:
            try:
                func(None, None)
            except ReferenceError:
                continue

    cdef unbind_widget(self, int uid):
        '''(internal) Unbind all the handlers created by the rules of the
        widget. The :attr:`kivy.uix.widget.Widget.uid` is passed here
        instead of the widget itself, because we are using it in the
        widget destructor.

        .. versionadded:: 1.7.2
        '''
        if uid not in _handlers:
            return
        for f, k, fn in _handlers[uid]:
            try:
                f.unbind(**{k: fn})
            except ReferenceError:
                # proxy widget is already gone, that's cool :)
                pass
        del _handlers[uid]

    cdef _build_canvas(self, object canvas, object widget, object rule, object rootrule):
        global Instruction
        if Instruction is None:
            Instruction = Factory.get('Instruction')
        idmap = copy(self.rulectx[rootrule]['ids'])
        for crule in rule.children:
            name = crule.name
            if name == 'Clear':
                canvas.clear()
                continue
            instr = Factory.get(name)()
            if not isinstance(instr, Instruction):
                raise BuilderException(
                    crule.ctx, crule.line,
                    'You can add only graphics Instruction in canvas.')
            try:
                for prule in crule.properties.values():
                    key = prule.name
                    value = prule.co_value
                    if type(value) is CodeType:
                        value = create_handler(
                            widget, instr.proxy_ref,
                            key, value, prule, idmap, True)
                    setattr(instr, key, value)
            except Exception as e:
                raise BuilderException(
                    prule.ctx, prule.line,
                    '{}: {}'.format(e.__class__.__name__, e))
