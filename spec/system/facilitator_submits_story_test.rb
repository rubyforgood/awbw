require 'rails_helper'

RSpec.describe "Facilitators can submit a story", type: :system do 
  describe "Share Your Story form" do 
    context "When facilitator is logged in" do 
      before do 

         create(:windows_type, :adult)
        create(:windows_type, :children)
        create(:windows_type, :combined)
         @windows_type = WindowsType.find_by(name: "ADULT")
        @workshop = create(:workshop)

           @facilitator1 = create(:user)
        create(:facilitator, user: @facilitator1)

          @story_idea = create(:story_idea,
          title: "My Workshop Experience",
          workshop: @workshop,
          windows_type: @windows_type,
          created_by: @facilitator1,  # IMPORTANT: Created by this user
          project: create(:project)   # Might need a project
        )

        @user = create(:user)
        create(:facilitator, user: @user)



        sign_in @user
        visit new_story_path
      end 

      it "shows the New Story form" do
        expect(page).to have_content("New Story")
        expect(page).to have_field("Title")
        expect(page).to have_field("Body")
      end

          it "can fill out and submit a story with workshop context" do 
        fill_in 'Title', with: 'Healing Through Art: My Journey with AWBW'
        
        check 'Published' if page.has_field?('Published')
        check 'Featured' if page.has_field?('Featured')
        #select @workshop.title from: 'story_workshop_id'
        select 'ADULT', from: 'story_windows_type_id'   
        #select 'Some Organization name', from: 'Organization'
        
        fill_in 'Body *', with: <<~STORY
          After losing my beloved wife Coral to a barracuda attack, 
          I became overly protective of our only remaining son, Nemo. 
          When Nemo was captured by divers and taken to Sydney, 
          I embarked on an impossible journey across the ocean.
          
          Through AWBW's workshops, I learned to process my grief and anxiety. 
          The art therapy sessions helped me express the fear I felt when 
          I thought I lost everything. Creating visual representations of 
          the Great Barrier Reef allowed me to reconnect with joyful memories 
          of Coral, rather than just the trauma of her loss.
          
          Today, Nemo is safely home with me. We still miss Coral every day, 
          but we've learned to honor her memory through art. We paint together, 
          creating colorful scenes of anemone gardens that remind us both 
          that beauty can grow even in the deepest pain.
        STORY
        
        fill_in 'Youtube url', with: 'https://youtube.com/watch?v=2zLkasScy7A'
        fill_in 'Website url', with: 'https://awbw.org/success-stories'
        
        # File uploads
        if page.has_field?('Primary media')
          attach_file 'Primary media', Rails.root.join('spec/fixtures/some_image.jpg')
        end
        
        if page.has_field?('Secondary media 1')
          attach_file 'Secondary media 1', Rails.root.join('spec/fixtures/some_image.jpg')
        end
        
       
        select @user.name, from: 'story_created_by_id'
        select @story_idea.title, from: 'story_story_idea_id'
        select @facilitator1.name, from: 'story_spotlighted_facilitator_id'
        # Submit
        click_button 'Create Story'

        expect.(page).to have_content("Story was successfully created.")
        expect(page).to have_content('Healing Through Art')

        expect(page).to have_current_path(stories_path)

        it "can cancel the form" do
        click_link 'Cancel'
        expect(page).not_to have_content('stories')
        expect(page).to have_current_path(stories_path)
      end
    end 
    end 
  end 
end