+++
title = "Cpp Concept-based Interface with ADL-based Customization Point"
description = ""
date = 2025-10-22

[taxonomies]
categories = ["Post"]
tags = ["C++"]

[extra]
toc = true
+++

First of all, we need a well defined Cpp20 concept `BitserySerializable`, which is used for restricting `toBytes` and `fromBytes` type
parameter. In other words, this is trying to tell the compiler who only has the function `serialize` and satisfies the function signature
is allowed to use `toBytes` and `fromBytes`. And this is done by Cpp20 concept-based interface.

```cpp
using Bytes = std::vector<std::byte>;

template<typename T>
concept BitserySerializable = requires(T obj,
    bitsery::Serializer<bitsery::OutputBufferAdapter<Bytes>>& ser,
    bitsery::Deserializer<bitsery::InputBufferAdapter<Bytes>>& des) {
    { serialize(ser, obj) } -> std::same_as<void>;
    { serialize(des, obj) } -> std::same_as<void>;
};
```

And then is our template function `toBytes` and `fromBytes`:

```cpp
template<BitserySerializable T>
[[nodiscard]] Bytes toBytes(const T& value) {
    Bytes buffer;
    auto writtenSize = bitsery::quickSerialization<bitsery::OutputBufferAdapter<Bytes>>(
        buffer, const_cast<T&>(value)); // bitsery requires non-const
    buffer.resize(writtenSize); // trim to exact used size
    return buffer;
}

template<BitserySerializable T>
[[nodiscard]] T fromBytes(const Bytes& buffer) {
    T value{};
    auto result = bitsery::quickDeserialization<bitsery::InputBufferAdapter<Bytes>>(
        {buffer.begin(), buffer.end()}, value);
    if (result.first != bitsery::ReaderError::NoError)
        throw std::runtime_error("Deserialization error: bad data format.");
    if (!result.second)
        throw std::runtime_error("Deserialization error: incomplete read.");
    return value;
}
```

The use case is simple as well. For example, we got a schema:

```cpp
enum class Cat : uint16_t
{
    V1,
    V2,
    V3
};

struct User
{
    std::string name;
    std::vector<std::string> tags;
    Cat category;
    uint age;
};

```

Next user defines his own `void serialize(S& s, User& user)`. When bitsery calls `serialize(ser, obj)`, it looks for:

1. In the same namespace as 'obj' (`User`);
2. Via ADL (Argument-Dependent Lookup) in associated namespaces.

Custom `serialize` function:

```cpp
template <typename S>
void serialize(S& s, User& user)
{
    s.text1b(user.name, 100);
    s.container(user.tags, 10, [](auto& s, std::string& str)
                { s.text1b(str, 50); });
    s.value2b(user.category);
    s.value4b(user.age);
}
```

Finally, the test case:

```cpp
// Usage
int main()
{
    User u{"Alice", {"dev", "cpp"}, Cat::V2, 30};

    Bytes bytes = toBytes(u);
    User restored = fromBytes<User>(bytes);

    std::cout << "Restored: " << restored.name << ", age " << restored.age << "\n";
}
```

Oh, don't forget our import:

```cpp
#include <bitsery/adapter/buffer.h>
#include <bitsery/bitsery.h>
#include <bitsery/traits/string.h>
#include <bitsery/traits/vector.h>

#include <concepts>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
```

Above all, we've used Cpp20 concept-based interface and ADL-based customization point to create an external serialization example.
To sum up, the benefits of this approach:

- Non-intrusive: Don't need to modify existing classes;
- Separation of concerns: Serialization logic separate from business logic;
- Flexibility: Can provide different serialization strategies for the same type;
- Template-friendly: Works well with generic code;
- No inheritance required: Works with value types, third-party types, etc.
