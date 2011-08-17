SimpleNavigation::Configuration.run do |navigation|  
  navigation.items do |primary|
    primary.item :dashboard, t('nav.dashboard'), root_path
    primary.item :overview, t('nav.overview'), overview_path
    primary.item :barclamps, t('nav.barclamps'), barclamp_index_barclamp_path
    primary.item :proposals, t('nav.proposals'), barclamp_proposals_barclamp_path
    primary.item :roles, t('nav.roles'), barclamp_roles_barclamp_path
    primary.item :help, t('nav.help'), '/users_guide.pdf', { :link => { :target => "_blank" } }
    primary.item :eula, t('nav.eula'), '/dell_eula.html', { :link => { :target => "_blank" } }
  end
end
