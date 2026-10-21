import importlib.util
from pathlib import Path

_spec = importlib.util.spec_from_file_location("patch_tool_persist", Path(__file__).with_name("patch-tool-persist.py"))
ptp = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ptp)

BUILD_296 = b"x;var G1=50000,REr=4000,pSe=128000,y=1;"
BUILD_299 = b"x;var WH=50000,Oxr=1e4,T2n=4000,D8e=128000,ife=500000;"
BUILD_300 = b"x;var mD=50000,PMr=1e4,Gqn=4000,gXe=128000,hme=500000;"


def test_apply_build_296_layout_patched():
    assert ptp.apply(BUILD_296, "t") == b"x;var G1=2000 ,REr=4000,pSe=128000,y=1;"


def test_apply_build_299_inserted_constant_patched():
    assert ptp.apply(BUILD_299, "t") == b"x;var WH=2000 ,Oxr=1e4,T2n=4000,D8e=128000,ife=500000;"


def test_apply_build_300_renamed_constants_patched():
    assert ptp.apply(BUILD_300, "t") == b"x;var mD=2000 ,PMr=1e4,Gqn=4000,gXe=128000,hme=500000;"


def test_apply_patched_length_unchanged():
    assert len(ptp.apply(BUILD_300, "t")) == len(BUILD_300)


def test_apply_already_patched_returns_same_object():
    patched = ptp.apply(BUILD_300, "t")
    assert ptp.apply(patched, "t") is patched


def test_apply_no_anchor_returns_none():
    assert ptp.apply(b"var a=1,b=2;", "t") is None


def test_apply_value_without_neighbours_returns_none():
    assert ptp.apply(b"var mD=50000,Gqn=4001,gXe=128000,", "t") is None


def test_apply_stock_and_patched_both_present_returns_none():
    assert ptp.apply(BUILD_300 + ptp.apply(BUILD_296, "t"), "t") is None


def test_apply_empty_input_returns_none():
    assert ptp.apply(b"", "t") is None
