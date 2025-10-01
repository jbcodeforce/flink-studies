# 1. Create a ServiceAccount
kubectl create serviceaccount admin-user -n kubernetes-dashboard

# 2. Bind the 'admin-user' ServiceAccount to the 'cluster-admin' role
kubectl create clusterrolebinding admin-user-binding \
  --clusterrole=cluster-admin \
  --serviceaccount=kubernetes-dashboard:admin-user