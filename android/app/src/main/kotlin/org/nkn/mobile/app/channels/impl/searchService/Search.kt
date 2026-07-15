package org.nkn.mobile.app.channels.impl.searchService

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.nkn.mobile.app.channels.IChannelHandler
import search.Search
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class SearchService : IChannelHandler, MethodChannel.MethodCallHandler, EventChannel.StreamHandler, ViewModel() {
    
    companion object {
        lateinit var methodChannel: MethodChannel
        const val METHOD_CHANNEL_NAME = "org.nkn.mobile/native/search"
        
        lateinit var eventChannel: EventChannel
        const val EVENT_CHANNEL_NAME = "org.nkn.mobile/native/search_event"
        private var eventSink: EventChannel.EventSink? = null
        
        // Store search client instances by ID
        private val clients = ConcurrentHashMap<String, search.SearchClient>()
        
        fun register(flutterEngine: FlutterEngine) {
            SearchService().install(flutterEngine.dartExecutor.binaryMessenger)
        }
    }
    
    override fun install(binaryMessenger: BinaryMessenger) {
        methodChannel = MethodChannel(binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)
    }
    
    override fun uninstall() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "newSearchClient" -> newSearchClient(call, result)
            "newSearchClientWithAuth" -> newSearchClientWithAuth(call, result)
            "query" -> query(call, result)
            "submitUserData" -> submitUserData(call, result)
            "verify" -> verify(call, result)
            "queryByID" -> queryByID(call, result)
            "getMyInfo" -> getMyInfo(call, result)
            "getPublicKeyHex" -> getPublicKeyHex(call, result)
            "getAddress" -> getAddress(call, result)
            "isVerified" -> isVerified(call, result)
            "disposeClient" -> disposeClient(call, result)
            else -> result.notImplemented()
        }
    }
    
    // Create a query-only search client
    private fun newSearchClient(call: MethodCall, result: MethodChannel.Result) {
        val apiBase = call.argument<String>("apiBase") ?: ""
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val client = Search.newSearchClient(apiBase)
                if (client == null) {
                    resultError(result, "CREATE_CLIENT_FAILED", "Failed to create search client")
                    return@launch
                }
                
                // Generate unique ID for this client
                val clientId = UUID.randomUUID().toString()
                clients[clientId] = client
                
                val response = hashMapOf<String, Any>(
                    "clientId" to clientId
                )
                
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Create an authenticated search client
    private fun newSearchClientWithAuth(call: MethodCall, result: MethodChannel.Result) {
        val apiBase = call.argument<String>("apiBase") ?: ""
        val seed = call.argument<ByteArray>("seed")
        
        if (seed == null || seed.size != 32) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "INVALID_SEED", "Seed must be exactly 32 bytes")
            }
            return
        }
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val client = Search.newSearchClientWithAuth(apiBase, seed)
                if (client == null) {
                    resultError(result, "CREATE_AUTH_CLIENT_FAILED", "Failed to create authenticated search client")
                    return@launch
                }
                
                // Generate unique ID for this client
                val clientId = UUID.randomUUID().toString()
                clients[clientId] = client
                
                val response = hashMapOf<String, Any>(
                    "clientId" to clientId
                )
                
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Query data by keyword
    private fun query(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        val keyword = call.argument<String>("keyword") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val response = client.query(keyword)
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Submit user data
    private fun submitUserData(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        var nknAddress = call.argument<String>("nknAddress") ?: ""
        val customId = call.argument<String>("customId") ?: ""
        val nickname = call.argument<String>("nickname") ?: ""
        val phoneNumber = call.argument<String>("phoneNumber") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.Default) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        // Use Dispatchers.Default for CPU-intensive PoW calculation
        // Default dispatcher is optimized for CPU-bound work
        viewModelScope.launch(Dispatchers.Default) {
            try {
                // Process nknAddress: if empty, use publicKey
                val publicKeyHex = client.publicKeyHex ?: ""
                
                if (nknAddress.isEmpty()) {
                    nknAddress = publicKeyHex
                } else {
                    // Validate format if contains dot
                    if (nknAddress.contains(".")) {
                        val parts = nknAddress.split(".")
                        if (parts.size != 2) {
                            resultError(result, "INVALID_PARAMETER", 
                                      "Invalid nknAddress format. Expected: identifier.publickey")
                            return@launch
                        }
                        val providedPubKey = parts[1]
                        if (providedPubKey.lowercase() != publicKeyHex.lowercase()) {
                            resultError(result, "INVALID_PARAMETER", 
                                      "nknAddress publickey suffix must match your actual publicKey")
                            return@launch
                        }
                    } else {
                        // If no dot, must equal publicKey
                        if (nknAddress.lowercase() != publicKeyHex.lowercase()) {
                            resultError(result, "INVALID_PARAMETER", 
                                      "nknAddress must be either \"identifier.publickey\" format or equal to publicKey")
                            return@launch
                        }
                    }
                }
                
                // Validate customId if provided
                if (customId.isNotEmpty() && customId.length < 3) {
                    resultError(result, "INVALID_PARAMETER", 
                              "customId must be at least 3 characters if provided")
                    return@launch
                }
                
                client.submitUserData(nknAddress, customId, nickname, phoneNumber)
                val response = hashMapOf<String, Any>(
                    "success" to true
                )
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Verify the client (optional, for query operations)
    private fun verify(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.Default) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        // Use Dispatchers.Default for CPU-intensive PoW calculation
        viewModelScope.launch(Dispatchers.Default) {
            try {
                client.verify()
                val response = hashMapOf<String, Any>(
                    "success" to true
                )
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }

    // Query by ID
    private fun queryByID(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        val id = call.argument<String>("id") ?: ""

        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val response = client.queryByID(id)
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }

    // Get my info by nknAddress
    private fun getMyInfo(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        val address = call.argument<String>("address") ?: ""

        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }

        viewModelScope.launch(Dispatchers.IO) {
            try {
                val response = client.getMyInfo(address)
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Get public key hex
    private fun getPublicKeyHex(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val publicKeyHex = client.publicKeyHex
                resultSuccess(result, publicKeyHex)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Get wallet address
    private fun getAddress(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val address = client.address
                resultSuccess(result, address)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Check if verified
    private fun isVerified(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        
        val client = clients[clientId]
        if (client == null) {
            viewModelScope.launch(Dispatchers.IO) {
                resultError(result, "CLIENT_NOT_FOUND", "Search client not found")
            }
            return
        }
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                val verified = client.isVerified
                resultSuccess(result, verified)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
    
    // Dispose client
    private fun disposeClient(call: MethodCall, result: MethodChannel.Result) {
        val clientId = call.argument<String>("clientId") ?: ""
        
        viewModelScope.launch(Dispatchers.IO) {
            try {
                clients.remove(clientId)
                val response = hashMapOf<String, Any>(
                    "success" to true
                )
                resultSuccess(result, response)
            } catch (e: Exception) {
                resultError(result, e)
            }
        }
    }
}
