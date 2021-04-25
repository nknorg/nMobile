# nkn-sdk-flutter
## Usage
### install
```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Wallet.install();
  Client.install();
  runApp(MyApp());
}
```

### Wallet

Create wallet:

```dart
Wallet wallet = await Wallet.create(null, config: WalletConfig(password: '123'));
print(wallet.address);
print(wallet.seed);
print(wallet.publicKey);
```

Export wallet to JSON string, where sensitive contents are encrypted by password provided in config:

```dart
wallet.keystore;
```

By default the wallet will use RPC server provided by nkn.org. Any NKN full node can serve as a RPC server. To create a wallet using customized RPC server:

```dart
Wallet wallet = await Wallet.create(null, config: WalletConfig(password: '123', seedRPCServerAddr: ['http://seed.nkn.org:30003']));
print(wallet.address);
print(wallet.seed);
print(wallet.publicKey);
```

Load wallet from JSON string, note that the password needs to be the same as the one provided when creating wallet:

```dart
Wallet wallet = await Wallet.restore(w.keystore,
    config: WalletConfig(password: '123'));
print(wallet.address);
print(wallet.seed);
print(wallet.publicKey);
                      
```

Query asset balance for this wallet:

```dart
double balance = await wallet.getBalance();
```

Transfer asset to some address:

```dart
String txHash = await wallet.transfer(NKN_ADDRESS, '1.23');
```

### Client

NKN Client provides low level p2p messaging through NKN network.

Create a client with a generated key pair:

 ```dart
var client = await Client.create(WALLET_SEED);
```

Listen for connection established:


```dart
client.onConnect.listen((event) {
    print(event.node);
});
```

Receive data from other clients

```dart
client.onMessage.listen((event) {
    print(event.type);
    print(event.encrypted);
    print(event.messageId);
    print(event.data);
    print(event.src);
});
```

Send text message to other clients

```dart
await client.sendText([CLIENT_ADDRESS], jsonEncode({'contentType': 'text', 'content': 'Hello'}));
```

publish a message to a specified topic (see wallet section for subscribing to topics):


```dart
await client.publishText(TOPIC, jsonEncode({'contentType': 'text', 'content': 'Hello'}));
```

Pub/Sub

```dart
var res = await client.subscribe(topic: TOPIC);
var res = await client.unsubscribe(topic: TOPIC);
var res = await client.getSubscribersCount(topic: TOPIC);
var res = await client.getSubscription(topic: TOPIC, subscriber: CLIENT_ADDRESS);
```