from nativeedge.exceptions import NonRecoverableError
from nativeedge.state import ctx_parameters as inputs

if inputs.get("verify_tags"):
    if len(set(inputs["service_tags"])) != len(inputs["service_tags"]):
        raise NonRecoverableError('Service_tags should be unique.')