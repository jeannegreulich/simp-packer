class site::workstations {
  include ::gdm
  include ::gnome

  Class[Gdm] -> Class[Gnome]
  # Make sure everyone can log into all nodes.
  # If you want to change this, simply remove this line and add
  # individual entries to your nodes as appropriate
  pam::access::rule { 'Allow Users':
    comment => 'Allow all users in the "users" group to access the system from anywhere.',
    users   => ['(users)'],
    origins => ['ALL']
  }

}
