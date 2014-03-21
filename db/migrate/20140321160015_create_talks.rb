class CreateTalks < ActiveRecord::Migration
  def change
    # improvements we could make:
    # speakers as an hstore
    # separate model for conferences and add a conference_id
    create_table :talks do |t|
      t.integer :year
      t.string  :title
      t.string  :speaker
      t.text    :abstract
      t.text    :bio
    end
  end
end
