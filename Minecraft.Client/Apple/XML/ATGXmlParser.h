#pragma once
namespace ATG {
class ISAXCallback {
public:
    virtual ~ISAXCallback() {}
};
class XMLParser {
public:
    XMLParser();
    ~XMLParser();
    HRESULT ParseXMLBuffer(const char* strBuffer, unsigned int uBufferSize);
    void RegisterSAXCallbackInterface(ISAXCallback* pISAXCallback);
};
}
