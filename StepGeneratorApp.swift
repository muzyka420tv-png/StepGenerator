import SwiftUI
import HealthKit

@main
struct StepGeneratorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var healthManager = HealthManager()
    @State private var stepCount: String = "10000"
    @State private var timer: Timer?
    @State private var isRunning = false
    @State private var statusMessage = "Bezczynny"
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Generator Kroków")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            TextField("Cel kroków", text: $stepCount)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.horizontal, 40)
            
            Text("Status: \(statusMessage)")
                .foregroundColor(isRunning ? .green : .gray)
            
            HStack(spacing: 30) {
                Button(action: startGeneration) {
                    Text("Start")
                        .font(.title2)
                        .frame(width: 100, height: 50)
                        .background(isRunning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(isRunning)
                
                Button(action: stopGeneration) {
                    Text("Stop")
                        .font(.title2)
                        .frame(width: 100, height: 50)
                        .background(isRunning ? Color.red : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(!isRunning)
            }
            
            Button(action: requestPermissions) {
                Text("Poproś o uprawnienia HealthKit")
                    .font(.headline)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    func startGeneration() {
        guard let target = Double(stepCount), target > 0 else {
            statusMessage = "Nieprawidłowa liczba kroków"
            return
        }
        
        let totalDuration: TimeInterval = 1800
        let interval: TimeInterval = 60
        let batches = Int(totalDuration / interval)
        let stepsPerBatch = target / Double(batches)
        
        var batchIndex = 0
        isRunning = true
        statusMessage = "Generuję \(Int(target)) kroków..."
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if batchIndex >= batches {
                timer.invalidate()
                isRunning = false
                statusMessage = "Zakończono: \(Int(target)) kroków"
                return
            }
            
            batchIndex += 1
            let stepsThisBatch = batchIndex == batches
                ? target - (Double(batchIndex - 1) * stepsPerBatch)
                : stepsPerBatch
            
            healthManager.writeSteps(stepsThisBatch)
            statusMessage = "Paczka \(batchIndex)/\(batches) - \(Int(stepsThisBatch)) kroków"
        }
    }
    
    func stopGeneration() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        statusMessage = "Zatrzymano"
    }
    
    func requestPermissions() {
        healthManager.requestAuthorization { success in
            statusMessage = success ? "Uprawnienia przyznane" : "Odmówiono"
        }
    }
}

class HealthManager: ObservableObject {
    private let healthStore = HKHealthStore()
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }
        
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let typesToWrite: Set<HKSampleType> = [stepType]
        let typesToRead: Set<HKObjectType> = [stepType]
        
        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                completion(success && error == nil)
            }
        }
    }
    
    func writeSteps(_ steps: Double) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let quantity = HKQuantity(unit: HKUnit.count(), doubleValue: steps)
        let now = Date()
        let sample = HKQuantitySample(
            type: stepType,
            quantity: quantity,
            start: now.addingTimeInterval(-30),
            end: now
        )
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("Błąd: \(error.localizedDescription)")
            }
        }
    }
}
