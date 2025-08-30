#ifndef __WEBRELAY_WEBSOCKETS_V2_UTIL_UTILS_MQH__
#define __WEBRELAY_WEBSOCKETS_V2_UTIL_UTILS_MQH__
#property strict

namespace WebRelay
{

class CUtils
{
public:
    // Validates UTF-8 encoding per RFC 3629
    static bool IsValidUtf8(const string str)
    {
        uchar bytes[];
        int len = StringToCharArray(str, bytes, 0, WHOLE_ARRAY, CP_UTF8);
        if(len > 0 && bytes[len-1] == 0) len--; // Exclude null terminator
        int i = 0;
        while(i < len)
        {
            if(bytes[i] < 0x80) { i++; continue; }
            if(bytes[i] >= 0xC2 && bytes[i] <= 0xDF && i + 1 < len &&
               bytes[i+1] >= 0x80 && bytes[i+1] <= 0xBF) { i += 2; continue; }
            if(bytes[i] >= 0xE0 && bytes[i] <= 0xEF && i + 2 < len &&
               bytes[i+1] >= 0x80 && bytes[i+1] <= 0xBF && bytes[i+2] >= 0x80 && bytes[i+2] <= 0xBF)
               { i += 3; continue; }
            if(bytes[i] >= 0xF0 && bytes[i] <= 0xF4 && i + 3 < len &&
               bytes[i+1] >= 0x80 && bytes[i+1] <= 0xBF && bytes[i+2] >= 0x80 && bytes[i+2] <= 0xBF &&
               bytes[i+3] >= 0x80 && bytes[i+3] <= 0xBF) { i += 4; continue; }
            return false;
        }
        return true;
    }

    // Converts string to byte array without null terminator
    static void StringToBytesNoNull(const string s, uchar &out[])
    {
        ArrayFree(out);
        int n = StringToCharArray(s, out, 0, WHOLE_ARRAY, CP_UTF8);
        if(n > 0 && out[n-1] == 0) ArrayResize(out, n-1);
    }

    // Generates random bytes for masking or key generation
    static void GenerateRandomBytes(uchar &key[], int size)
    {
        ArrayResize(key, size);
        for(int i = 0; i < size; i++)
            key[i] = (uchar)MathRand();
    }

    // Returns Base64 alphabet
    static void GetBase64Alphabet(uchar &alphabet[])
    {
        const uchar b64[] =
        {
            'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
            'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
            'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
            'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
        };
        ArrayResize(alphabet, ArraySize(b64));
        ArrayCopy(alphabet, b64);
    }

    // Validates WebSocket close codes per RFC 6455
    static bool IsValidCloseCode(const int code)
    {
        return (code >= 1000 && code <= 1015) || (code >= 3000 && code <= 4999);
    }
};

} // namespace WebRelay
#endif