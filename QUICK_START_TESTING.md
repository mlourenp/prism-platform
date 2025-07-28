# Prism v1.2 - Quick Start Testing Guide

**🚀 Execute Phase 1 Testing in 15 Minutes**

This guide provides the fastest path to run comprehensive baseline benchmarks of your Prism v1.2 infrastructure platform deployment.

---

## ⚡ **Quick Start Commands**

### **1. Setup Test Environment (5 minutes)**
```bash
# Navigate to Prism directory
cd prism/

# Setup monitoring infrastructure
./scripts/setup-test-monitoring.sh

# Verify prerequisites
terraform --version  # >= 1.0
kubectl version --client  # >= 1.28
helm version  # >= 3.8
```

### **2. Run Full Test Suite (10 minutes)**
```bash
# Execute complete Phase 1 testing
./scripts/run-phase1-tests.sh --category=all --provider=aws

# OR run specific test categories:
./scripts/run-phase1-tests.sh --category=infrastructure
./scripts/run-phase1-tests.sh --category=performance
```

### **3. View Results (Immediate)**
```bash
# Access monitoring dashboards
kubectl port-forward -n monitoring svc/grafana-test 3000:3000 &
kubectl port-forward -n monitoring svc/prometheus-test 9090:9090 &

# Check test results
ls -la test-results/phase1/
cat test-results/phase1/PHASE_1_TEST_RESULTS_*.md
```

---

## 🎯 **Testing Scenarios Available**

### **Quick Tests (2-5 minutes each)**
```bash
# Test 1: Minimal Stack (Basic functionality)
cd examples/aws/minimal-stack/
terraform apply -auto-approve
./scripts/run-baseline-performance-test.sh minimal-stack
terraform destroy -auto-approve

# Test 2: eBPF Performance Validation
./scripts/run-baseline-performance-test.sh ebpf-test
```

### **Standard Tests (10-15 minutes each)**
```bash
# Test 3: Complete infrastructure with observability
./scripts/run-phase1-tests.sh --category=infrastructure --provider=aws

# Test 4: Multi-cloud deployment
./scripts/run-phase1-tests.sh --category=multi-cloud
```

### **Comprehensive Tests (30-45 minutes)**
```bash
# Full Phase 1 validation suite
./scripts/run-phase1-tests.sh --parallel=true --cleanup=true
```

---

## 📊 **Monitoring Your Tests**

### **Real-Time Monitoring**
```bash
# Terminal 1: Watch cluster resources
watch -n 5 'kubectl top nodes && echo "---" && kubectl top pods --all-namespaces'

# Terminal 2: Monitor test progress
watch -n 10 'ls -la test-results/phase1/ | tail -5'

# Terminal 3: Access Grafana dashboard
kubectl port-forward -n monitoring svc/grafana-test 3000:3000
# Open: http://localhost:3000 (admin/prism-test-2024)
```

### **Key Metrics to Watch**
- **CPU Usage**: Should stay < 80% under load
- **Memory Usage**: Should stay < 85% under load  
- **Pod Creation Time**: Should be < 30 seconds
- **Network Latency**: Should be < 100ms for inter-pod communication
- **Error Rate**: Should be < 0.1% during tests

---

## 🎯 **Expected Baseline Results**

### **Infrastructure Metrics**
| Metric | Minimal Stack | Standard Stack | Complete Stack |
|--------|---------------|----------------|----------------|
| **Deployment Time** | < 15 min | < 25 min | < 45 min |
| **Node Count** | 2-3 nodes | 3-5 nodes | 5-8 nodes |
| **Pod Count** | < 20 pods | 30-50 pods | 50-100 pods |
| **Memory Usage** | < 4GB | < 16GB | < 32GB |
| **CPU Usage** | < 2 cores | < 8 cores | < 16 cores |
| **Monthly Cost** | < $50 | < $200 | < $500 |

### **Performance Targets**
| Metric | Target | Good | Excellent |
|--------|---------|------|-----------|
| **Response Time (P95)** | < 500ms | < 200ms | < 100ms |
| **Throughput** | > 100 RPS | > 500 RPS | > 1000 RPS |
| **Pod Creation** | < 60s | < 30s | < 15s |
| **Network Latency** | < 100ms | < 50ms | < 10ms |
| **eBPF Acceleration** | > 10% improvement | > 20% | > 30% |

---

## 🔧 **Troubleshooting Quick Fixes**

### **Common Issues & Solutions**

#### **Terraform Apply Fails**
```bash
# Clean slate and retry
terraform destroy -auto-approve
rm -rf .terraform/ terraform.tfstate*
terraform init
terraform apply -auto-approve
```

#### **Pods Not Starting**
```bash
# Check cluster resources
kubectl describe nodes
kubectl get events --sort-by=.metadata.creationTimestamp

# Check specific pod issues
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace>
```

#### **Monitoring Not Working**
```bash
# Restart monitoring setup
kubectl delete namespace monitoring
./scripts/setup-test-monitoring.sh

# Check monitoring pod status
kubectl get pods -n monitoring
kubectl logs -l app=prometheus-test -n monitoring
```

#### **Performance Tests Failing**
```bash
# Check cluster health
kubectl cluster-info
kubectl get nodes

# Verify test prerequisites
./scripts/run-baseline-performance-test.sh --help
```

---

## 🚦 **Test Status Indicators**

### **Success Indicators**
- ✅ All pods in `Running` state
- ✅ Terraform apply completes without errors
- ✅ Monitoring dashboards accessible
- ✅ Performance metrics within target ranges
- ✅ Cost estimates match expectations

### **Warning Indicators**  
- ⚠️  Some pods in `Pending` state (resource constraints)
- ⚠️  Performance slightly below targets
- ⚠️  Higher than expected resource usage
- ⚠️  Monitoring data gaps

### **Failure Indicators**
- ❌ Terraform apply fails repeatedly
- ❌ Pods crash looping
- ❌ Performance significantly below targets
- ❌ Monitoring completely unavailable
- ❌ Cost estimates exceed budget by >50%

---

## 📋 **Quick Validation Checklist**

### **Before Testing**
- [ ] Cloud provider credentials configured
- [ ] kubectl connected to target cluster
- [ ] Terraform initialized
- [ ] Monitoring namespace available

### **During Testing**
- [ ] All pods reach `Running` state
- [ ] No error events in cluster
- [ ] Resource usage within limits
- [ ] Network connectivity working
- [ ] Monitoring collecting data

### **After Testing**
- [ ] Test results generated
- [ ] Performance metrics collected
- [ ] Cost analysis completed
- [ ] Cleanup successful (if enabled)
- [ ] Baseline documented

---

## 🔄 **Next Steps After Phase 1**

### **If Tests Pass**
```bash
# Document baselines
cp test-results/phase1/PHASE_1_TEST_RESULTS_*.md docs/baselines/

# Proceed to Phase 2
./scripts/run-phase2-tests.sh  # (Coming soon)

# Schedule regular testing
echo "0 2 * * 1 cd /path/to/prism && ./scripts/run-phase1-tests.sh" | crontab -
```

### **If Tests Fail**
```bash
# Collect debug information
kubectl get events --sort-by=.metadata.creationTimestamp > debug_events.txt
kubectl describe nodes > debug_nodes.txt

# Review logs
kubectl logs -l app=prism-platform --all-containers=true > debug_logs.txt

# Open issue with debug data
# GitHub: https://github.com/your-org/prism/issues/new
```

---

## 🆘 **Quick Help**

**Need immediate help?**
```bash
# Check the troubleshooting guide
cat docs/troubleshooting.md

# View test logs
tail -f test-results/phase1/*.log

# Get cluster status
kubectl get all --all-namespaces
```

**Have 5 minutes? Run this first:**
```bash
./scripts/run-baseline-performance-test.sh quick-test
```

**Have 15 minutes? Run this:**
```bash
./scripts/run-phase1-tests.sh --category=infrastructure --provider=aws
```

**Have 45 minutes? Run everything:**
```bash
./scripts/run-phase1-tests.sh --parallel=true
```

---

**🚀 Ready to start? Execute this command:**
```bash
cd prism/ && ./scripts/run-phase1-tests.sh
``` 