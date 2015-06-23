# encoding: UTF-8
require 'spec_helper'

describe ActiveData::Model::Associations do
  context do
    before do
      stub_model(:nobody) do
        include ActiveData::Model::Associations
      end
      stub_model(:project) do
        include ActiveData::Model::Lifecycle
      end
      stub_model(:user, Nobody) do
        include ActiveData::Model::Associations
        embeds_many :projects
      end
      stub_model(:manager, Nobody) do
        include ActiveData::Model::Associations
        embeds_one :managed_project, class_name: 'Project'
      end
      stub_model(:admin, User) do
        include ActiveData::Model::Associations
        embeds_many :admin_projects, class_name: 'Project'
      end
    end

    describe '#reflections' do
      specify { expect(Nobody.reflections.keys).to eq([]) }
      specify { expect(User.reflections.keys).to eq([:projects]) }
      specify { expect(Manager.reflections.keys).to eq([:managed_project]) }
      specify { expect(Admin.reflections.keys).to eq([:projects, :admin_projects]) }
    end

    describe '#reflect_on_association' do
      specify { expect(Nobody.reflect_on_association(:blabla)).to be_nil }
      specify { expect(Admin.reflect_on_association('projects')).to be_a ActiveData::Model::Associations::Reflections::EmbedsMany }
      specify { expect(Manager.reflect_on_association(:managed_project)).to be_a ActiveData::Model::Associations::Reflections::EmbedsOne }
    end
  end

  context 'class determine errors' do
    specify do
      expect { stub_model do
        include ActiveData::Model::Associations

        embeds_one :author, class_name: 'Borogoves'
      end.reflect_on_association(:author).klass }.to raise_error(/Can not determine class for `#<Class:\w+>#author` association/)
    end

    specify do
      expect { stub_model(:user) do
        include ActiveData::Model::Associations

        embeds_many :projects, class_name: 'Borogoves' do
          attribute :title
        end
      end.reflect_on_association(:projects).klass }.to raise_error 'Can not determine superclass for `User#projects` association'
    end
  end

  context do
    before do
      stub_model(:project) do
        include ActiveData::Model::Lifecycle

        attribute :title, type: String

        validates :title, presence: true
      end

      stub_model(:profile) do
        include ActiveData::Model::Lifecycle

        attribute :first_name, type: String
        attribute :last_name, type: String
      end

      stub_model(:user) do
        include ActiveData::Model::Associations

        embeds_many :projects
        embeds_one :profile
      end
    end

    let(:user) { User.new }

    its(:projects) { should = [] }
    its(:profile) { should = nil }

    describe '#association' do
      specify { expect(user.association(:projects)).to be_a(ActiveData::Model::Associations::EmbedsMany) }
      specify { expect(user.association(:profile)).to be_a(ActiveData::Model::Associations::EmbedsOne) }
    end

    describe '#association_names' do
      specify { expect(user.association_names).to eq([:projects, :profile]) }
    end

    describe '#save_associations!' do
      let(:project) { Project.new title: 'Project' }
      let(:profile) { Profile.new first_name: 'Name' }
      let(:user) { User.new(profile: profile, projects: [project]) }

      specify { expect { user.save_associations! }.to change { user.read_attribute(:profile) }.from(nil).to('first_name' => 'Name', 'last_name' => nil) }
      specify { expect { user.save_associations! }.to change { user.read_attribute(:projects) }.from(nil).to([{'title' => 'Project'}]) }

      context do
        let(:project) { Project.new }
        specify { expect { user.save_associations! }.to raise_error ActiveData::AssociationNotSaved }
      end
    end

    describe '#==' do
      let(:project) { Project.new title: 'Project' }
      let(:other) { Project.new title: 'Other' }

      specify { expect(User.new(projects: [project])).to eq(User.new(projects: [project])) }
      specify { expect(User.new(projects: [project])).not_to eq(User.new(projects: [other])) }
      specify { expect(User.new(projects: [project])).not_to eq(User.new) }

      context do
        before { User.send(:include, ActiveData::Model::Primary) }
        let(:user) { User.new(projects: [project]) }

        specify { expect(user).to eq(user.clone.tap { |b| b.projects(author: project) }) }
        specify { expect(user).to eq(user.clone.tap { |b| b.projects(author: other) }) }
      end
    end
  end
end
