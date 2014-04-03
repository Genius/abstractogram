class CreateTalks < ActiveRecord::Migration
  def change
    create_table :talks do |t|
      t.integer :year
      t.string  :title
      t.string  :speaker
      t.text    :abstract
      t.text    :bio
    end
    
    # improvements we could make:
    # add conference_id, have a separate model for conferences
    # better handling of talks with multiple speakers: maybe a speaker model and a join table
  end
end
