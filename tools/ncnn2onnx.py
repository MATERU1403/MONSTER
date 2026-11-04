# (used by tools/clean_johan.py: python -I tools/ncnn2onnx.py <x2.param> <x2.bin> <out.onnx>)
# realesr-animevideov3 (SRVGGNetCompact) from its ncnn files into an ONNX graph that outputs the x4 result
import sys, struct, numpy as np, onnx
from onnx import helper, numpy_helper, TensorProto
param, binf, out = sys.argv[1:4]
lines = open(param).read().split('\n')[2:]
data = open(binf, 'rb').read(); pos = 0
def take_weights(n):
    global pos
    tag = struct.unpack_from('<I', data, pos)[0]; pos += 4
    if tag == 0x01306B47:
        w = np.frombuffer(data, np.float16, n, pos).astype(np.float32); pos += n * 2
        pos = (pos + 3) // 4 * 4
    elif tag == 0:
        w = np.frombuffer(data, np.float32, n, pos).copy(); pos += n * 4
    else:
        raise SystemExit('weight tag %x' % tag)
    return w
def take_raw(n):
    global pos
    w = np.frombuffer(data, np.float32, n, pos).copy(); pos += n * 4
    return w
nodes, inits = [], []
prev, cin, idx = 'input', 3, 0
for line in lines:
    parts = line.split()
    if not parts: continue
    kind = parts[0]
    args = dict(p.split('=') for p in parts[6:] if '=' in p) if len(parts) > 6 else {}
    if kind == 'Convolution':
        cout, size = int(args['0']), int(args['1'])
        w = take_weights(int(args['6'])).reshape(cout, cin, size, size)
        b = take_raw(cout) if args.get('5') == '1' else np.zeros(cout, np.float32)
        wn, bn, on = f'w{idx}', f'b{idx}', f'c{idx}'
        inits += [numpy_helper.from_array(w, wn), numpy_helper.from_array(b, bn)]
        nodes.append(helper.make_node('Conv', [prev, wn, bn], [on], pads=[1, 1, 1, 1], kernel_shape=[3, 3]))
        prev, cin = on, cout
    elif kind == 'PReLU':
        n = int(args['0']); s = take_raw(n).reshape(n, 1, 1)
        sn, on = f's{idx}', f'p{idx}'
        inits.append(numpy_helper.from_array(s, sn))
        nodes.append(helper.make_node('PRelu', [prev, sn], [on])); prev = on
    elif kind == 'PixelShuffle':
        nodes.append(helper.make_node('DepthToSpace', [prev], ['shuf'], blocksize=int(args['0']), mode='CRD')); prev = 'shuf'
    idx += 1
print('weights used', pos, 'of', len(data))
inits.append(numpy_helper.from_array(np.array([1, 1, 4, 4], np.float32), 'scales'))
nodes.append(helper.make_node('Resize', ['input', '', 'scales'], ['base'], mode='nearest'))
nodes.append(helper.make_node('Add', ['shuf', 'base'], ['output']))
graph = helper.make_graph(nodes, 'animevideov3', [helper.make_tensor_value_info('input', TensorProto.FLOAT, [1, 3, None, None])],
                          [helper.make_tensor_value_info('output', TensorProto.FLOAT, [1, 3, None, None])], inits)
model = helper.make_model(graph, opset_imports=[helper.make_opsetid('', 17)], ir_version=9)
onnx.checker.check_model(model)
onnx.save(model, out)
