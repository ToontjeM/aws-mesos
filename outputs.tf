output "master-public_ip" {
  value = aws_instance.mesos-master.public_ip
}
output "master-private_ip" {
  value = aws_instance.mesos-master.private_ip
}
output "slave-public_ip" {
  value = aws_instance.mesos-slave.public_ip
}
output "slave-private_ip" {
  value = aws_instance.mesos-slave.private_ip
}