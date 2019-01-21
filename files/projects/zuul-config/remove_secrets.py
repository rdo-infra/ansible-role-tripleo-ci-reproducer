#!/usr/bin/env python
import sys
import yaml


path = sys.argv[1]
with open(path) as f:
    t = f.read()
y = yaml.load(t)
p = []
for i in y:
    if i.get('job'):
        i['job'].pop('secrets', None)
    p.append(i)
with open(path, "w") as f:
    yaml.dump(p, f, default_flow_style=False)
