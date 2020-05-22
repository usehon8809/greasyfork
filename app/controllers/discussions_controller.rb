class DiscussionsController < ApplicationController
  include DiscussionHelper

  before_action :authenticate_user!, only: :create
  before_action :moderators_only, only: :destroy

  def index
    @discussions = Discussion
                   .includes(:poster, :script)
                   .order(stat_last_reply_date: :desc)
    case script_subset
    when :sleazyfork
      @discussions = @discussions.where(scripts: { sensitive: true })
    when :greasyfork
      @discussions = @discussions.where.not(scripts: { sensitive: true })
    when :all
      # No restrictions
    else
      raise "Unknown subset #{script_subset}"
    end

    @discussions = @discussions.paginate(page: params[:page], per_page: 25)
  end

  def show
    @discussion = discussion_scope.find(params[:id])

    if @discussion.script
      case script_subset
      when :sleazyfork
        unless @discussion.script.sensitive?
          render_404
          return
        end
      when :greasyfork
        if @discussion.script.sensitive?
          render_404
          return
        end
      when :all
        # No restrictions
      else
        raise "Unknown subset #{script_subset}"
      end
    end

    @comment = Comment.new
    render layout: 'scripts' if @script
  end

  def create
    discussion = discussion_scope.build(discussion_params)
    discussion.poster = discussion.comments.first.poster = current_user
    discussion.script = @script
    discussion.save!
    discussion.comments.first.notify_script_authors!
    redirect_to discussion.path
  end

  def destroy
    discussion = discussion_scope.find(params[:id])
    discussion.destroy!
    if discussion.script
      redirect_to script_path(discussion.script)
    else
      redirect_to root_path
    end
  end

  private

  def discussion_scope
    if params[:script_id]
      @script = Script.find(params[:script_id])
      @script.new_discussions
    else
      Discussion
    end
  end

  def discussion_params
    params.require(:discussion).permit(:rating, comments_attributes: [:text, :text_markup])
  end
end