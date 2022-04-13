output "master-public_ip" {
  value = aws_instance.mesos-master.public_ip
}
output "slave-public_ip" {
  value = aws_instance.mesos-slave.public_ip
}