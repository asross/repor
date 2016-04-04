FactoryGirl.define do
  [:post, :comment].each do |type|
    factory type do
      transient { author nil }

      before(:create) do |record, evaluator|
        if evaluator.author
          author = Author.find_or_create_by(name: evaluator.author)
          record.author_id = author.id
        end
      end
    end
  end
end
