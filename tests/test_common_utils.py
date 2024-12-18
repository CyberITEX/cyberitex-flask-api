from common.utils.common_utils import authenticate_api_key

def test_some_utility_function():
    """Test some utility function."""
    result = authenticate_api_key('input_value')
    assert result == True
