import sys, os, locale, re

encoding = locale.getpreferredencoding()

def makeEscape():
  value = sys.argv[1]
  value = re.sub('(\\\\*)([ \\t])', '\\1\\1\\\\\\2', value)
  value = re.sub('(\\\\*)$', '\\1\\1', value)
  sys.stdout.write(value)

def getParentDir():
  directory = sys.argv[1]
  directory = os.path.dirname(os.path.abspath(directory))
  sys.stdout.write(directory)

def _deepEncode(value):
  if isinstance(value, dict):
    return {_deepEncode(k): _deepEncode(v) for k, v in value.items()}
  if isinstance(value, list):
    return [_deepEncode(e) for e in value]
  if isinstance(value, unicode):
    return value.encode(encoding)
  return value

def _deepDecode(value):
  if isinstance(value, dict):
    return {_deepDecode(k): _deepDecode(v) for k, v in value.items()}
  if isinstance(value, list):
    return [_deepDecode(e) for e in value]
  if isinstance(value, str):
    return value.decode(encoding)
  return value

def _getErrorDescription(error):
  info = CF.CFErrorCopyUserInfo(error)
  if info is not None:
    try:
      return info['NSDebugDescription']
    except KeyError:
      pass
  return CF.CFErrorCopyDescription(error)

def _readPList(f):
  data = f.read()
  properties, _, error = CF.CFPropertyListCreateWithData(
    None, CF.CFDataCreateWithBytesNoCopy(
      None, data, len(data), CF.kCFAllocatorNull
    ), CF.kCFPropertyListMutableContainersAndLeaves, None, None
  )
  if error is not None:
    raise RuntimeError(_getErrorDescription(error).encode(encoding))
  return properties

def _writePList(properties, f):
  data, error = CF.CFPropertyListCreateData(
    None, properties, CF.kCFPropertyListXMLFormat_v1_0, 0, None
  )
  if error is not None:
    raise RuntimeError(_getErrorDescription(error).encode(encoding))
  if data is None:
    raise RuntimeError('Failed to serialize properties')
  f.write(data)

def getBoolean(value):
  return bool(distutils.util.strtobool(str(value)))

def _processSettings(properties, settings):
  keys = settings[0::2]
  expressions = settings[1::2]
  if len(expressions) < len(keys):
    expressions.append('None')

  for key, expression in zip(keys, expressions):
    key = key.decode(encoding)
    try:
      value = _deepEncode(properties[key])
    except KeyError:
      value = None

    value = eval(expression, globals(), {'value': value})

    if value is None:
      try:
        del properties[key]
      except KeyError:
        pass
    else:
      properties[key] = _deepDecode(value)

def processPList():
  global CF, distutils
  import CoreFoundation as CF, distutils.util

  plist = sys.argv[1]

  with open(plist, 'rb') as f:
    properties = _readPList(f)

  _processSettings(properties, sys.argv[2:])

  with os.fdopen(os.dup(sys.stdout.fileno()), 'wb') as f:
    _writePList(properties, f)

def _getCurrentVariables(argv):
  variables = argv[0::2]
  values = argv[1::2]
  if len(values) < len(variables):
    values.append('')

  result = {}
  noop = False
  for k, v in zip(variables, values):
    if k.startswith('.') or k.startswith('MAKE') or \
       k == '-*-command-variables-*-' or \
       k.startswith('__CF_') or \
       k == 'SHLVL' or k == 'OLDPWD' or k == '_' or \
       k.endswith('DIR'):
      continue
    if k == 'MFLAGS':
      if re.match('-\\w*n', v) is not None:
        noop = True
      continue

    try:
      if v == os.environ[k]:
        continue
    except KeyError:
      pass

    result[k.decode(encoding)] = v.decode(encoding)
  return result, noop

def checkAndSaveMakeVariables():
  import json

  varsfile = sys.argv[1]
  makefile = sys.argv[2]

  try:
    with open(varsfile, 'rb') as f:
      saved = json.load(f)
  except:
    saved = {}

  current, noop = _getCurrentVariables(sys.argv[3:])

  if current != saved:
    if not noop:
      with open(varsfile, 'wb') as f:
        json.dump(current, f, indent=2)
      os.utime(makefile, None)
    sys.stdout.write('1')
