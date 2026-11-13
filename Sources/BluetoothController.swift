import Foundation
import CoreBluetooth
import Network

final class BluetoothController: NSObject, ObservableObject, CBPeripheralManagerDelegate {
    @Published var status = "Bluetooth stopped" {
        didSet { if status != oldValue { appLog.write("BLUETOOTH",status,key:"bt-"+status,every:2) } }
    }
    private var manager: CBPeripheralManager?
    private var output: CBMutableCharacteristic?
    private var central: CBCentral?
    private var connections: [UInt8:NWConnection] = [:]
    private var decoder = BluetoothWire.Decoder()
    private var pending: [String:(UInt8,Data)] = [:]
    private var frames: [Data] = []
    private var sequence: UInt8 = 0
    private var name = "P1 MotionRemote"
    func start(player: Int, identity: String) {
        stop(); name = "P\(player) \(identity)"
        manager = CBPeripheralManager(delegate:self,queue:.main)
    }
    func stop() {
        manager?.stopAdvertising(); manager?.removeAllServices(); manager?.delegate = nil; manager = nil
        for c in connections.values { c.cancel() }; connections.removeAll()
        central = nil; output = nil; frames = []; pending = [:]; decoder = .init()
        status = "Bluetooth stopped"
    }
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        guard peripheral === manager else { return }
        guard peripheral.state == .poweredOn else {
            status = peripheral.state == .unauthorized ? "Allow Bluetooth in Settings → Privacy & Security" : "Turn on Bluetooth"
            return
        }
        let rx = CBMutableCharacteristic(type:CBUUID(string:BluetoothWire.input),properties:[.write,.writeWithoutResponse],value:nil,permissions:[.writeEncryptionRequired])
        let tx = CBMutableCharacteristic(type:CBUUID(string:BluetoothWire.output),properties:[.notify,.notifyEncryptionRequired],value:nil,permissions:[])
        output = tx
        let service = CBMutableService(type:CBUUID(string:BluetoothWire.service),primary:true)
        service.characteristics = [rx,tx]; peripheral.add(service)
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else { status = error!.localizedDescription; return }
        peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[CBUUID(string:BluetoothWire.service)],CBAdvertisementDataLocalNameKey:name])
        status = "Bluetooth ready · select this phone in Dolphin Connections"
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard self.central == nil || self.central?.identifier == central.identifier else { return }
        self.central = central; status = "Bluetooth linked · waiting for Dolphin inputs"
        // The default interval is tuned for battery life and delays controller input.
        peripheral.setDesiredConnectionLatency(.low,for:central)
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard self.central?.identifier == central.identifier else { return }
        for c in connections.values { c.cancel() }; connections.removeAll()
        self.central = nil; pending = [:]; frames = []; decoder = .init()
        status = "Bluetooth disconnected · reconnect in Dolphin"
    }
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        guard requests.allSatisfy({ central?.identifier == $0.central.identifier && $0.characteristic.uuid == CBUUID(string:BluetoothWire.input) && $0.offset == 0 && $0.value != nil }) else {
            peripheral.respond(to:first,withResult:.writeNotPermitted); return
        }
        for r in requests {
            if let value = r.value, let (route,data) = decoder.accept(value,now:ProcessInfo.processInfo.systemUptime) { forward(data,route:route) }
        }
        peripheral.respond(to:first,withResult:.success)
    }

    private func forward(_ data: Data, route: UInt8) {
        if let c = connections[route] { c.send(content:data,completion:.contentProcessed { _ in }); return }
        guard connections.count < 16 else { return }
        let c = NWConnection(host:"127.0.0.1",port:26760,using:.udp)
        connections[route] = c; c.start(queue:.main); receive(c,route:route)
        c.send(content:data,completion:.contentProcessed { _ in })
    }
    private func receive(_ c: NWConnection, route: UInt8) {
        c.receiveMessage { [weak self,weak c] data,_,_,error in
            guard let self, let c, self.connections[route] === c else { return }
            if let data {
                let b = [UInt8](data)
                let type = b.count >= 20 ? UInt32(b[16])|UInt32(b[17])<<8|UInt32(b[18])<<16|UInt32(b[19])<<24 : 0
                // Attitude packets only feed the Wi-Fi monitor; they would halve the radio budget here.
                if type != 0x100006 {
                    // Replace unsent motion snapshots instead of accumulating seconds of old input.
                    // Port replies come four at once (pads 0–3); keying by pad keeps the connected one.
                    self.pending["\(route):\(type):\(b.count > 20 ? b[20] : 0)"] = (route,data)
                    self.flush()
                }
                if type == 0x100002 { self.status = "Bluetooth · controller data active" }
            }
            if error == nil { self.receive(c,route:route) }
        }
    }
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) { flush() }
    private func flush() {
        guard let central, let manager, let output else { return }
        while true {
            if frames.isEmpty {
                guard let key = pending.keys.sorted().first, let (route,data) = pending.removeValue(forKey:key) else { return }
                sequence &+= 1
                frames = BluetoothWire.frames(data,route:route,sequence:sequence,mtu:central.maximumUpdateValueLength)
            }
            guard let first = frames.first else { return }
            guard manager.updateValue(first,for:output,onSubscribedCentrals:[central]) else { return }
            frames.removeFirst()
        }
    }
}
