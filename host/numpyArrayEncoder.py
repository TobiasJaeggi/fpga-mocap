import json
import numpy as np

# https://pynative.com/python-serialize-numpy-ndarray-into-json/
# https://stackoverflow.com/questions/26646362/numpy-array-is-not-json-serializable
# https://github.com/mpld3/mpld3/issues/434#issuecomment-340255689
class NumpyArrayEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, np.integer):
            return int(obj)
        elif isinstance(obj, np.floating):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        else:
            return super(NumpyArrayEncoder, self).default(obj)