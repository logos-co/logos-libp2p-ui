.pragma library

var base58 = "[1-9A-HJ-NP-Za-km-z]"
var peerIdPattern = new RegExp("^(?:Qm" + base58 + "{44}|1" + base58 + "{19,199}|[bB][A-Za-z2-7]{20,200}|k[0-9a-z]{20,200}|z" + base58 + "{20,200})$")
var privateKeyPattern = /^(?:[0-9a-fA-F]{2})+$/
var multiaddressPattern = /^\/(?:ip4|ip6|dns|dns4|dns6|dnsaddr)\/[^\/\s]+(?:\/[a-z0-9][a-z0-9-]*(?:\/[^\/\s]+)?)*$/i
var transportPattern = /\/(?:tcp|udp)\/(\d{1,5})(?:\/|$)/
var cidV0Pattern = new RegExp("^Qm" + base58 + "{44}$")
var cidV1Pattern = /^(?:[bB][A-Za-z2-7]{20,200}|[kK][0-9A-Za-z]{20,200}|z[1-9A-HJ-NP-Za-km-z]{20,200})$/

function isPeerId(value) {
    return peerIdPattern.test(String(value).trim())
}

function isOptionalPrivateKey(value) {
    var key = String(value).trim()
    return key.length === 0 || privateKeyPattern.test(key)
}

function isCid(value) {
    var cid = String(value).trim()
    return cidV0Pattern.test(cid) || cidV1Pattern.test(cid)
}

function isMultiaddress(value) {
    var address = String(value).trim()
    if (!multiaddressPattern.test(address))
        return false

    var transport = transportPattern.exec(address)
    if (!transport || Number(transport[1]) > 65535)
        return false

    if (address.indexOf("/ip4/") === 0) {
        var octets = address.split("/")[2].split(".")
        if (octets.length !== 4)
            return false
        for (var index = 0; index < octets.length; ++index) {
            if (!/^\d{1,3}$/.test(octets[index]) || Number(octets[index]) > 255)
                return false
        }
    }
    return true
}

function areMultiaddresses(values) {
    if (values.length === 0)
        return false
    for (var index = 0; index < values.length; ++index) {
        if (!isMultiaddress(values[index]))
            return false
    }
    return true
}
